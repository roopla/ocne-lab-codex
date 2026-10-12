import com.google.gson.*;
import com.google.gson.stream.JsonReader;
import com.google.gson.stream.JsonToken;
import com.sun.net.httpserver.*;
import com.zaxxer.hikari.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.Pattern;

/** Append-only handover notes: idempotent inserts, no automatic transaction replay. */
public final class NotesServer {
  static final Gson JSON = new Gson();
  static final Pattern ID =
      Pattern.compile("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
  static final String MODE = env("STORE_MODE", "oracle"), POD = env("POD_NAME", "notes-local");

  static String env(String key, String fallback) {
    return System.getenv().getOrDefault(key, fallback);
  }

  record Note(String id, String text, String createdAt) {}

  record Result(Note item, boolean deduplicated, Map<String, Object> meta) {}

  record Listing(List<Note> items, Map<String, Object> meta) {}

  static final class Conflict extends Exception {}

  interface Store extends AutoCloseable {
    Map<String, Object> health() throws Exception;

    Listing read(String id) throws Exception;

    Result write(String id, String text) throws Exception;

    default void close() {}
  }

  static final class MemoryStore implements Store {
    final Map<String, Note> rows = new HashMap<>();

    public Map<String, Object> health() {
      return Map.of(
          "mode",
          "memory",
          "pod",
          POD,
          "instance",
          "DEMO (no RAC)",
          "pdb",
          "none",
          "service",
          "java-notes");
    }

    public synchronized Listing read(String id) {
      var values =
          id == null
              ? rows.values().stream()
                  .sorted(Comparator.comparing(Note::createdAt).thenComparing(Note::id).reversed())
                  .limit(100)
                  .toList()
              : rows.containsKey(id) ? List.of(rows.get(id)) : List.<Note>of();
      return new Listing(values, health());
    }

    public synchronized Result write(String id, String text) throws Conflict {
      if (rows.containsKey(id)) {
        var row = rows.get(id);
        if (!row.text().equals(text)) throw new Conflict();
        return new Result(row, true, health());
      }
      var row = new Note(id, text, Instant.now().toString());
      rows.put(id, row);
      return new Result(row, false, health());
    }
  }

  static final class OracleStore implements Store {
    final HikariDataSource pool;

    OracleStore() {
      var config = new HikariConfig();
      config.setJdbcUrl(
          "jdbc:oracle:thin:@"
              + Objects.requireNonNull(System.getenv("DB_DSN"), "DB_DSN required"));
      config.setUsername(Objects.requireNonNull(System.getenv("DB_USER"), "DB_USER required"));
      config.setPassword(
          Objects.requireNonNull(System.getenv("DB_PASSWORD"), "DB_PASSWORD required"));
      config.setMaximumPoolSize(2);
      config.setMinimumIdle(0);
      config.setConnectionTimeout(3000);
      config.setValidationTimeout(2000);
      config.setIdleTimeout(60000);
      config.setMaxLifetime(300000);
      config.setInitializationFailTimeout(-1);
      config.setAutoCommit(false);
      config.addDataSourceProperty("oracle.jdbc.ReadTimeout", "5000");
      config.addDataSourceProperty("oracle.net.CONNECT_TIMEOUT", "3000");
      config.addDataSourceProperty("oracle.jdbc.fanEnabled", "false");
      pool = new HikariDataSource(config);
    }

    Map<String, Object> meta(Connection c) throws SQLException {
      try (var st = c.createStatement()) {
        st.setQueryTimeout(5);
        try (var rs =
            st.executeQuery(
                "SELECT"
                    + " SYS_CONTEXT('USERENV','INSTANCE_NAME'),SYS_CONTEXT('USERENV','CON_NAME'),SYS_CONTEXT('USERENV','SERVICE_NAME')"
                    + " FROM dual")) {
          rs.next();
          if (!rs.getString(2).equals(env("EXPECTED_PDB", "LABPDB")))
            throw new SQLException("Wrong PDB");
          return Map.of(
              "mode",
              "oracle",
              "pod",
              POD,
              "instance",
              rs.getString(1),
              "pdb",
              rs.getString(2),
              "databaseService",
              rs.getString(3),
              "service",
              "java-notes");
        }
      }
    }

    public Map<String, Object> health() throws SQLException {
      try (var c = pool.getConnection();
          var st = c.createStatement()) {
        st.setQueryTimeout(5);
        try (var ignored = st.executeQuery("SELECT id FROM board_notes WHERE 1=0")) {
          return meta(c);
        }
      }
    }

    List<Note> select(Connection c, String id) throws SQLException {
      String sql =
          "SELECT id,body,TO_CHAR(created_at AT TIME ZONE"
              + " 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.FF3\"Z\"') FROM board_notes";
      sql +=
          id == null
              ? " ORDER BY created_at DESC,id DESC FETCH FIRST 100 ROWS ONLY"
              : " WHERE id=?";
      try (var st = c.prepareStatement(sql)) {
        st.setQueryTimeout(5);
        if (id != null) st.setString(1, id);
        try (var rs = st.executeQuery()) {
          var rows = new ArrayList<Note>();
          while (rs.next()) rows.add(new Note(rs.getString(1), rs.getString(2), rs.getString(3)));
          return rows;
        }
      }
    }

    public Listing read(String id) throws SQLException {
      try (var c = pool.getConnection()) {
        var m = meta(c);
        return new Listing(select(c, id), m);
      }
    }

    public Result write(String id, String text) throws Exception {
      try (var c = pool.getConnection()) {
        var m = meta(c);
        try (var st = c.prepareStatement("INSERT INTO board_notes(id,body) VALUES(?,?)")) {
          st.setQueryTimeout(5);
          st.setString(1, id);
          st.setString(2, text);
          st.executeUpdate();
          var row = select(c, id).getFirst();
          c.commit();
          return new Result(row, false, m);
        } catch (SQLException e) {
          // ORA-00001 is the only duplicate condition. A failed COMMIT remains unknown.
          c.rollback();
          if (e.getErrorCode() != 1) throw e;
          var rows = select(c, id);
          if (rows.isEmpty()) throw new SQLException("Duplicate row unavailable");
          if (!rows.getFirst().text().equals(text)) throw new Conflict();
          return new Result(rows.getFirst(), true, m);
        }
      }
    }

    public void close() {
      pool.close();
    }
  }

  static void send(HttpExchange ex, int code, Object body) throws IOException {
    byte[] bytes = JSON.toJson(body).getBytes(StandardCharsets.UTF_8);
    ex.getResponseHeaders().set("Content-Type", "application/json");
    ex.getResponseHeaders().set("Cache-Control", "no-store");
    ex.sendResponseHeaders(code, bytes.length);
    try (var out = ex.getResponseBody()) {
      out.write(bytes);
    }
    System.out.println(
        JSON.toJson(
            Map.of(
                "service",
                "java-notes",
                "status",
                code,
                "pod",
                POD,
                "trace",
                Optional.ofNullable(ex.getRequestHeaders().getFirst("X-Request-Trace"))
                    .orElse(""))));
  }

  static String[] validate(JsonElement parsed) {
    if (!parsed.isJsonObject()) throw new IllegalArgumentException();
    var o = parsed.getAsJsonObject();
    if (!o.keySet().equals(Set.of("id", "text"))) throw new IllegalArgumentException();
    for (String k : List.of("id", "text"))
      if (!o.get(k).isJsonPrimitive() || !o.get(k).getAsJsonPrimitive().isString())
        throw new IllegalArgumentException();
    String id = o.get("id").getAsString(), text = o.get("text").getAsString();
    if (!ID.matcher(id).matches()
        || text.isBlank()
        || text.getBytes(StandardCharsets.UTF_8).length > 800) throw new IllegalArgumentException();
    return new String[] {id, text};
  }

  static void handle(HttpExchange ex, Store store) throws IOException {
    String method = ex.getRequestMethod(), path = ex.getRequestURI().getPath();
    try {
      if (method.equals("GET") && path.equals("/livez")) {
        send(ex, 200, Map.of("ok", true, "pod", POD));
        return;
      }
      if (method.equals("GET") && path.equals("/readyz")) {
        send(ex, 200, store.health());
        return;
      }
      String id = path.startsWith("/notes/") ? path.substring(7) : null;
      if (!path.equals("/notes") && (id == null || !ID.matcher(id).matches())) {
        send(ex, 404, Map.of("error", "Route not found"));
        return;
      }
      if (method.equals("GET")) {
        var result = store.read(id);
        send(ex, id != null && result.items().isEmpty() ? 404 : 200, result);
        return;
      }
      if (!method.equals("POST") || id != null) {
        send(ex, 405, Map.of("error", "Use GET or POST on collection"));
        return;
      }
      if (!Optional.ofNullable(ex.getRequestHeaders().getFirst("Content-Type"))
          .orElse("")
          .startsWith("application/json")) {
        send(ex, 415, Map.of("error", "Use application/json"));
        return;
      }
      byte[] bytes = ex.getRequestBody().readNBytes(4097);
      if (bytes.length > 4096) {
        send(ex, 413, Map.of("error", "Body exceeds 4096 bytes"));
        return;
      }
      var reader = new JsonReader(new StringReader(new String(bytes, StandardCharsets.UTF_8)));
      reader.setStrictness(Strictness.STRICT);
      var parsed = JsonParser.parseReader(reader);
      if (reader.peek() != JsonToken.END_DOCUMENT) throw new IllegalArgumentException();
      var values = validate(parsed);
      var result = store.write(values[0], values[1]);
      send(ex, result.deduplicated() ? 200 : 201, result);
    } catch (Conflict e) {
      send(ex, 409, Map.of("error", "This id already has different text"));
    } catch (IllegalArgumentException
        | JsonParseException
        | com.google.gson.stream.MalformedJsonException e) {
      send(
          ex,
          400,
          Map.of("error", "Use id (lowercase UUID) and nonblank text, maximum 800 UTF-8 bytes"));
    } catch (Exception e) {
      System.err.println(
          JSON.toJson(
              Map.of(
                  "service",
                  "java-notes",
                  "errorType",
                  e.getClass().getSimpleName(),
                  "oracleCode",
                  e instanceof SQLException sql ? sql.getErrorCode() : 0)));
      send(
          ex,
          503,
          Map.of(
              "error",
              "Database unavailable",
              "outcome",
              method.equals("POST") ? "unknown" : "unavailable",
              "retrySameId",
              method.equals("POST"),
              "pod",
              POD));
    } finally {
      ex.close();
    }
  }

  public static void main(String[] args) throws Exception {
    if (!Set.of("oracle", "memory").contains(MODE))
      throw new IllegalArgumentException("STORE_MODE must be oracle or memory");
    Store store = MODE.equals("memory") ? new MemoryStore() : new OracleStore();
    var server =
        HttpServer.create(
            new InetSocketAddress(env("HOST", "0.0.0.0"), Integer.parseInt(env("PORT", "8083"))),
            32);
    var executor =
        new ThreadPoolExecutor(8, 8, 0, TimeUnit.MILLISECONDS, new ArrayBlockingQueue<>(16));
    server.setExecutor(executor);
    server.createContext("/", ex -> handle(ex, store));
    Runtime.getRuntime()
        .addShutdownHook(
            new Thread(
                () -> {
                  server.stop(10);
                  executor.shutdown();
                  store.close();
                }));
    server.start();
    System.out.println(JSON.toJson(Map.of("service", "java-notes", "mode", MODE, "pod", POD)));
  }
}
