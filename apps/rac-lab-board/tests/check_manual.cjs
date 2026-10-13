// Check the rendered manual without contacting the cluster or writing database rows.
const {createRequire}=require("node:module");
const path=require("node:path");
const {pathToFileURL}=require("node:url");
const assert=require("node:assert/strict");
const lab=path.resolve(__dirname,"../../..");
const puppeteer=createRequire(path.join(lab,"private/diagram-tools/package.json"))("puppeteer");
(async()=>{
 const browser=await puppeteer.launch({executablePath:process.env.BROWSER_PATH||"C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",headless:true});
 try {
  const page=await browser.newPage();
  await page.setViewport({width:1440,height:1100});
  await page.goto(pathToFileURL(path.join(lab,"apps/rac-lab-board/docs/MANUAL.html")).href,{waitUntil:"networkidle0"});
  const report=await page.evaluate(()=>({
   headings:document.querySelectorAll("h1,h2,h3").length,
   images:document.images.length,
   unloadedImages:[...document.images].filter(i=>!i.complete||i.naturalWidth===0).map(i=>i.getAttribute("src")),
   brokenAnchors:[...document.querySelectorAll('a[href^="#"]')].filter(a=>!document.getElementById(decodeURIComponent(a.getAttribute("href").slice(1)))).map(a=>a.getAttribute("href")),
   overflow:document.documentElement.scrollWidth>innerWidth
  }));
  assert.deepEqual(report.unloadedImages,[]);assert.deepEqual(report.brokenAnchors,[]);assert.equal(report.overflow,false);
  await page.screenshot({path:path.join(lab,"logs/rac-app-manual-desktop.png"),fullPage:false});
  await page.setViewport({width:390,height:844});
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  console.log("PASS: rendered manual",JSON.stringify(report),"mobile width fits");
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
