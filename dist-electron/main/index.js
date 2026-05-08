"use strict";const s=require("electron"),u=require("path"),n=require("electron-log"),K=require("better-sqlite3"),p=require("fs"),N=require("crypto");let f=null;const W=`
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS source_items (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL DEFAULT 'text',
  source TEXT NOT NULL DEFAULT 'manual',
  status TEXT NOT NULL DEFAULT 'inbox',
  title TEXT,
  content_path TEXT NOT NULL DEFAULT '',
  content_hash TEXT,
  preview_text TEXT,
  ocr_text TEXT,
  transcript TEXT,
  polished_transcript TEXT,
  source_app TEXT,
  original_url TEXT,
  tags TEXT NOT NULL DEFAULT '[]',
  capture_item_id TEXT,
  vault_import_path TEXT,
  asset_file_ids TEXT NOT NULL DEFAULT '[]',
  metadata TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_source_items_status ON source_items(status);
CREATE INDEX IF NOT EXISTS idx_source_items_created_at ON source_items(created_at);
CREATE INDEX IF NOT EXISTS idx_source_items_type ON source_items(type);

CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  applied_at INTEGER NOT NULL DEFAULT (unixepoch())
);
`;function Q(){const e=s.app.getPath("userData");return u.join(e,"acmind.db")}async function Z(){const e=Q(),t=u.dirname(e);p.existsSync(t)||p.mkdirSync(t,{recursive:!0}),n.info(`Opening database at: ${e}`),f=new K(e),f.pragma("journal_mode = WAL"),f.pragma("foreign_keys = ON"),f.exec(W),n.info("Database schema initialized")}function ee(){f&&(f.close(),f=null,n.info("Database closed"))}function m(){if(!f)throw new Error("Database not initialized");return f}function D(e){return{id:e.id,type:e.type,source:e.source,status:e.status,title:e.title,contentPath:e.content_path,contentHash:e.content_hash,previewText:e.preview_text,ocrText:e.ocr_text,transcript:e.transcript,polishedTranscript:e.polished_transcript,sourceApp:e.source_app,originalUrl:e.original_url,tags:JSON.parse(e.tags||"[]"),captureItemId:e.capture_item_id,vaultImportPath:e.vault_import_path,assetFileIds:JSON.parse(e.asset_file_ids||"[]"),metadata:JSON.parse(e.metadata||"{}"),createdAt:new Date(e.created_at*1e3),updatedAt:e.updated_at?new Date(e.updated_at*1e3):void 0}}function te(e){const t=m();let r="SELECT * FROM source_items WHERE 1=1";const a=[];return e!=null&&e.status&&(r+=" AND status = ?",a.push(e.status)),e!=null&&e.type&&(r+=" AND type = ?",a.push(e.type)),e!=null&&e.source&&(r+=" AND source = ?",a.push(e.source)),r+=" ORDER BY created_at DESC",e!=null&&e.limit&&(r+=" LIMIT ?",a.push(e.limit)),e!=null&&e.offset&&(r+=" OFFSET ?",a.push(e.offset)),t.prepare(r).all(...a).map(D)}function I(e){const r=m().prepare("SELECT * FROM source_items WHERE id = ?").get(e);return r?D(r):null}function T(e){const t=m(),r=crypto.randomUUID(),a=Math.floor(Date.now()/1e3);return t.prepare(`
    INSERT INTO source_items (
      id, type, source, status, title, content_path, content_hash,
      preview_text, ocr_text, transcript, polished_transcript,
      source_app, original_url, tags, capture_item_id, vault_import_path,
      asset_file_ids, metadata, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(r,e.type,e.source,e.status,e.title||null,e.contentPath||"",e.contentHash||null,e.previewText||null,e.ocrText||null,e.transcript||null,e.polishedTranscript||null,e.sourceApp||null,e.originalUrl||null,JSON.stringify(e.tags||[]),e.captureItemId||null,e.vaultImportPath||null,JSON.stringify(e.assetFileIds||[]),JSON.stringify(e.metadata||{}),a,a),I(r)}function x(e,t){const r=m(),a=Math.floor(Date.now()/1e3),i=[],o=[];return t.type!==void 0&&(i.push("type = ?"),o.push(t.type)),t.source!==void 0&&(i.push("source = ?"),o.push(t.source)),t.status!==void 0&&(i.push("status = ?"),o.push(t.status)),t.title!==void 0&&(i.push("title = ?"),o.push(t.title)),t.contentPath!==void 0&&(i.push("content_path = ?"),o.push(t.contentPath)),t.previewText!==void 0&&(i.push("preview_text = ?"),o.push(t.previewText)),t.ocrText!==void 0&&(i.push("ocr_text = ?"),o.push(t.ocrText)),t.transcript!==void 0&&(i.push("transcript = ?"),o.push(t.transcript)),t.tags!==void 0&&(i.push("tags = ?"),o.push(JSON.stringify(t.tags))),t.metadata!==void 0&&(i.push("metadata = ?"),o.push(JSON.stringify(t.metadata))),i.push("updated_at = ?"),o.push(a),o.push(e),r.prepare(`UPDATE source_items SET ${i.join(", ")} WHERE id = ?`).run(...o),I(e)}function re(e){m().prepare("DELETE FROM source_items WHERE id = ?").run(e)}function ae(e){const t=m(),r=`%${e}%`;return t.prepare(`
    SELECT * FROM source_items 
    WHERE title LIKE ? OR preview_text LIKE ? OR ocr_text LIKE ?
    ORDER BY created_at DESC
    LIMIT 50
  `).all(r,r,r).map(D)}function ne(){const e=m(),t=e.prepare("SELECT COUNT(*) as count FROM source_items").get().count,r=e.prepare("SELECT COUNT(*) as count FROM source_items WHERE status = 'inbox'").get().count,a=e.prepare("SELECT COUNT(*) as count FROM source_items WHERE status = 'distilled'").get().count,i=e.prepare("SELECT COUNT(*) as count FROM source_items WHERE status = 'exported'").get().count;return{total:t,inbox:r,distilled:a,exported:i}}function F(){const t=m().prepare("SELECT value FROM app_settings WHERE key = 'app_settings'").get();if(t)try{return JSON.parse(t.value)}catch{n.warn("Failed to parse settings, using defaults")}return{theme:"system",language:"zh-CN",vaultPath:"",autoCaptureClipboard:!0,defaultExportTarget:"obsidian",autoFrontmatter:!0,desktopCapsule:{isEnabled:!0,position:"top",autoHide:!0,showVoice:!0,showCapture:!0,showAgent:!0}}}function se(e){const t=m(),a={...F(),...e};return t.prepare(`
    INSERT OR REPLACE INTO app_settings (key, value) VALUES ('app_settings', ?)
  `).run(JSON.stringify(a)),a}let E=null;function q(){if(!E)throw new Error("Assets database not initialized");return E}async function oe(){const e=s.app.getPath("userData"),t=u.join(e,"assets"),r=u.join(e,"assets.db");p.existsSync(t)||p.mkdirSync(t,{recursive:!0}),E=new(require("better-sqlite3"))(r),E.exec(`
    CREATE TABLE IF NOT EXISTS asset_files (
      id TEXT PRIMARY KEY,
      source_item_id TEXT,
      kind TEXT NOT NULL,
      original_name TEXT,
      local_path TEXT NOT NULL,
      mime_type TEXT,
      size_bytes INTEGER,
      sha256 TEXT,
      created_at INTEGER NOT NULL DEFAULT (unixepoch()),
      metadata TEXT NOT NULL DEFAULT '{}'
    );
    
    CREATE INDEX IF NOT EXISTS idx_asset_files_source_item_id ON asset_files(source_item_id);
  `),n.info("AssetStore initialized at:",t)}function ie(){E&&(E.close(),E=null,n.info("AssetStore closed"))}function ce(e,t){const r=u.extname(e).toLowerCase();return{".png":"image",".jpg":"image",".jpeg":"image",".gif":"image",".webp":"image",".bmp":"image",".mp3":"audio",".wav":"audio",".m4a":"audio",".aac":"audio",".mp4":"video",".mov":"video",".avi":"video",".mkv":"video",".pdf":"pdf",".docx":"docx",".doc":"docx",".html":"html",".htm":"html",".md":"markdown",".markdown":"markdown"}[r]||"other"}function le(e){const t=p.readFileSync(e);return N.createHash("sha256").update(t).digest("hex")}function L(e,t,r,a){const i=q(),o=N.randomUUID(),l=s.app.getPath("userData"),d=u.join(l,"assets"),y=u.extname(t),h=`${o}${y}`,g=u.join(d,h);p.copyFileSync(r,g);const U=p.statSync(g),X=ce(g),k=le(g);return i.prepare(`
    INSERT INTO asset_files (id, source_item_id, kind, original_name, local_path, mime_type, size_bytes, sha256)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(o,null,X,t,g,null,U.size,k),{id:o,sourceItemId:e,kind:X,originalName:t,localPath:g,mimeType:a,sizeBytes:U.size,sha256:k,createdAt:new Date}}function de(e){const r=q().prepare("SELECT * FROM asset_files WHERE id = ?").get(e);return r?{id:r.id,sourceItemId:r.source_item_id,kind:r.kind,originalName:r.original_name,localPath:r.local_path,mimeType:r.mime_type,sizeBytes:r.size_bytes,sha256:r.sha256,createdAt:new Date(r.created_at*1e3),metadata:JSON.parse(r.metadata||"{}")}:null}function ue(e){try{const t=p.readFileSync(e),r=u.extname(e).toLowerCase();return`data:${{".png":"image/png",".jpg":"image/jpeg",".jpeg":"image/jpeg",".gif":"image/gif",".webp":"image/webp",".bmp":"image/bmp"}[r]||"application/octet-stream"};base64,${t.toString("base64")}`}catch(t){return n.error("Failed to read asset:",t),null}}let v=null,M="",O="",b=!1;function Y(){const e=s.clipboard.readText();return N.createHash("md5").update(e).digest("hex")}function H(){const e=s.clipboard.readImage();if(e.isEmpty())return"";const t=e.toPNG();return N.createHash("md5").update(t).digest("hex")}function P(e=1e3){if(b){n.warn("Clipboard monitor already running");return}M=Y(),O=H(),b=!0,n.info("Clipboard monitor started"),v=setInterval(()=>{ge()},e)}function C(){v&&(clearInterval(v),v=null),b=!1,n.info("Clipboard monitor stopped")}function pe(){return{watching:b,interval:b?1e3:0}}function he(){return b?C():P(),{watching:b}}async function ge(){try{const e=Y(),t=H();if(e&&e!==M){M=e;const r=s.clipboard.readText();if(r.trim()){const a=r.match(/^https?:\/\/[^\s]+$/);await T({type:a?"webpage":"text",source:"clipboard",status:"inbox",title:r.slice(0,50),previewText:r,originalUrl:a?r:void 0,contentPath:"",tags:[],assetFileIds:[],metadata:{capturedAt:Date.now()}}),$("clipboard:newItem",{type:"text",content:r}),n.info("Clipboard text captured:",r.slice(0,50))}}if(t&&t!==O){O=t;const r=s.clipboard.readImage();if(!r.isEmpty()){const a=r.toPNG(),i=`/tmp/clipboard_${Date.now()}.png`,o=require("fs");o.writeFileSync(i,a);const l=L(void 0,`clipboard_${Date.now()}.png`,i);await T({type:"image",source:"clipboard",status:"inbox",title:`截图 ${new Date().toLocaleString("zh-CN")}`,previewText:"剪贴板图片",contentPath:l.localPath,tags:[],assetFileIds:[l.id],metadata:{capturedAt:Date.now()}}),$("clipboard:newItem",{type:"image",assetId:l.id}),n.info("Clipboard image captured"),o.unlinkSync(i)}}}catch(e){n.error("Clipboard check error:",e)}}function $(e,t){s.BrowserWindow.getAllWindows().forEach(a=>{a.isDestroyed()||a.webContents.send(e,t)})}let w=null;async function fe(){try{const e=s.screen.getPrimaryDisplay(),{width:t,height:r}=e.size,a=await s.desktopCapturer.getSources({types:["screen"],thumbnailSize:{width:t,height:r}});return a.length>0?a[0].thumbnail.toDataURL():null}catch(e){return n.error("Full screen capture failed:",e),null}}async function me(e){try{const t=s.screen.getPrimaryDisplay(),r=await s.desktopCapturer.getSources({types:["screen"],thumbnailSize:t.size});if(r.length===0)return null;const a=r[0].thumbnail;return a.crop({x:Math.round(e.x*(a.getSize().width/t.size.width)),y:Math.round(e.y*(a.getSize().height/t.size.height)),width:Math.round(e.width*(a.getSize().width/t.size.width)),height:Math.round(e.height*(a.getSize().height/t.size.height))}).toDataURL()}catch(t){return n.error("Region capture failed:",t),null}}async function ye(e){try{const t=e?await me(e):await fe();if(!t)return null;const r=t.replace(/^data:image\/\w+;base64,/,""),a=Buffer.from(r,"base64"),i=`screenshot_${Date.now()}.png`,o=u.join(s.app.getPath("temp"),i);p.writeFileSync(o,a);const l=L(void 0,i,o);return await T({type:"screenshot",source:"screenshot",status:"captured",title:`截图 ${new Date().toLocaleString("zh-CN")}`,previewText:"屏幕截图",contentPath:l.localPath,tags:[],assetFileIds:[l.id],metadata:{capturedAt:Date.now(),rect:e}}),p.unlinkSync(o),{dataUrl:t,localPath:l.localPath}}catch(t){return n.error("Capture and save failed:",t),null}}function we(e){w&&w.close();const t=s.screen.getPrimaryDisplay(),{width:r,height:a}=t.bounds;t.scaleFactor,w=new s.BrowserWindow({x:t.bounds.x,y:t.bounds.y,width:r,height:a,frame:!1,transparent:!0,alwaysOnTop:!0,skipTaskbar:!0,resizable:!1,movable:!1,fullscreenable:!1,webPreferences:{nodeIntegration:!1,contextIsolation:!0}}),w.setIgnoreMouseEvents(!1),w.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(`
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          width: 100vw;
          height: 100vh;
          cursor: crosshair;
          user-select: none;
        }
        #overlay {
          position: absolute;
          top: 0; left: 0;
          width: 100%; height: 100%;
          background: rgba(0, 0, 0, 0.3);
        }
        #selection {
          position: absolute;
          border: 2px solid #f97316;
          background: transparent;
          box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.5);
        }
        #info {
          position: absolute;
          bottom: 20px;
          left: 50%;
          transform: translateX(-50%);
          background: rgba(0,0,0,0.8);
          color: white;
          padding: 8px 16px;
          border-radius: 6px;
          font-family: system-ui;
          font-size: 14px;
        }
      </style>
    </head>
    <body>
      <div id="overlay"></div>
      <div id="selection"></div>
      <div id="info">拖动选择区域，按 ESC 取消</div>
      <script>
        const overlay = document.getElementById('overlay');
        const selection = document.getElementById('selection');
        let isSelecting = false;
        let startX, startY;

        overlay.addEventListener('mousedown', (e) => {
          isSelecting = true;
          startX = e.clientX;
          startY = e.clientY;
          selection.style.left = startX + 'px';
          selection.style.top = startY + 'px';
          selection.style.width = '0';
          selection.style.height = '0';
        });

        overlay.addEventListener('mousemove', (e) => {
          if (!isSelecting) return;
          const currentX = e.clientX;
          const currentY = e.clientY;
          const left = Math.min(startX, currentX);
          const top = Math.min(startY, currentY);
          const width = Math.abs(currentX - startX);
          const height = Math.abs(currentY - startY);
          selection.style.left = left + 'px';
          selection.style.top = top + 'px';
          selection.style.width = width + 'px';
          selection.style.height = height + 'px';
        });

        overlay.addEventListener('mouseup', (e) => {
          if (!isSelecting) return;
          isSelecting = false;
          const currentX = e.clientX;
          const currentY = e.clientY;
          const left = Math.min(startX, currentX);
          const top = Math.min(startY, currentY);
          const width = Math.abs(currentX - startX);
          const height = Math.abs(currentY - startY);
          
          if (width > 10 && height > 10) {
            window.electronAPI.sendSelection({ x: left, y: top, width, height });
          } else {
            window.close();
          }
        });

        document.addEventListener('keydown', (e) => {
          if (e.key === 'Escape') {
            window.close();
          }
        });
      <\/script>
    </body>
    </html>
  `)}`),w.on("closed",()=>{w=null})}let _=[{id:"ollama-default",name:"Ollama (本地)",type:"ollama",tier:"local_light",baseUrl:"http://localhost:11434",modelId:"llama3.2",enabled:!0,capabilities:["chat","completion"]}];function j(){return _}function J(e){return _.find(t=>t.id===e)}function A(){return _.find(e=>e.enabled)}function Te(e){const t=_.findIndex(r=>r.id===e.id);t>=0?_[t]=e:_.push(e),n.info("Provider added/updated:",e.id)}async function R(e,t,r){var i;const a=J(e)||A();if(!a)throw new Error("No AI provider available");n.info(`AI chat request to ${a.name} (${a.modelId})`);try{const o=await fetch(`${a.baseUrl}/api/chat`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({model:a.modelId,messages:t.map(l=>({role:l.role,content:l.content})),stream:!!r})});if(!o.ok)throw new Error(`AI request failed: ${o.status}`);if(!r){const l=await o.json();return{content:((i=l.message)==null?void 0:i.content)||"",usage:l.usage,provider:a.name,model:a.modelId}}}catch(o){throw n.error("AI chat error:",o),o}}async function Ee(e,t,r){const a=J(e)||A();if(!a)throw new Error("No AI provider available");n.info(`AI completion request to ${a.name} (${a.modelId})`);try{const i=await fetch(`${a.baseUrl}/api/generate`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({model:a.modelId,prompt:t,stream:!!r})});if(!i.ok)throw new Error(`AI request failed: ${i.status}`);if(!r){const o=await i.json();return{content:o.response||"",usage:o.usage,provider:a.name,model:a.modelId}}}catch(i){throw n.error("AI completion error:",i),i}}const be=`你是一个知识蒸馏助手。请将用户提供的内容提炼成结构化的笔记。

输出格式要求（JSON）：
{
  "title": "提炼的标题（少于30字）",
  "summary": "100字以内的摘要",
  "tags": ["标签1", "标签2", "标签3"],
  "suggestedFolder": "建议的Obsidian文件夹",
  "bodyMarkdown": "详细的Markdown格式笔记内容，包含:
- 关键概念
- 核心要点（用列表）
- 相关思考
- 行动建议（如有）",
  "qualityFlags": ["insightful", "actionable", "reference"] // 质量标记
}

请只输出JSON，不要有其他内容。`;async function B(e){try{const t=I(e);if(!t)return{success:!1,error:"Source item not found"};n.info("Starting distillation for:",t.id),await x(e,{status:"distilling"});const r=t.previewText||t.ocrText||t.transcript||"";if(!r.trim())return{success:!1,error:"No content to distill"};const a=A();if(!a)return{success:!1,error:"No AI provider configured"};const i=[{role:"system",content:be},{role:"user",content:`请蒸馏以下内容：

${r}`}],o=await R(a.id,i);let l={};try{const h=o.content.match(/\{[\s\S]*\}/);h&&(l=JSON.parse(h[0]))}catch(h){n.warn("Failed to parse AI response as JSON:",h)}const d={id:crypto.randomUUID(),sourceItemIds:[e],title:l.title||t.title||"无标题",summary:l.summary||"",tags:l.tags||[],suggestedFolder:l.suggestedFolder,bodyMarkdown:l.bodyMarkdown||r,qualityFlags:l.qualityFlags||[],modelProvider:a.name,modelName:a.modelId,reviewStatus:"pending",createdAt:new Date,updatedAt:new Date},y=await T({type:"text",source:"distilled",status:"distilled",title:d.title,previewText:d.summary,contentPath:"",tags:d.tags,assetFileIds:t.assetFileIds,metadata:{distilledNoteId:d.id,bodyMarkdown:d.bodyMarkdown,qualityFlags:d.qualityFlags,modelProvider:d.modelProvider,modelName:d.modelName}});return await x(e,{status:"distilled"}),n.info("Distillation completed:",y.id),{success:!0,distilledNote:{...d,id:y.id}}}catch(t){return n.error("Distillation failed:",t),{success:!1,error:t instanceof Error?t.message:"Unknown error"}}}async function _e(e){const t=[];for(const r of e){const a=await B(r);t.push(a)}return t}async function Se(e){const t=A();if(!t)throw new Error("No AI provider configured");const r=[{role:"system",content:"你是一个知识提炼助手。请用简洁的语言总结以下内容，突出关键要点。"},{role:"user",content:e}];return(await R(t.id,r)).content}function Ie(e){const t=e.metadata||{},r=e.tags||[],a=new Date(e.createdAt).toISOString().split("T")[0],i=e.updatedAt?new Date(e.updatedAt).toISOString().split("T")[0]:a;let o=`---
`;o+=`title: "${e.title||"无标题"}"
`,o+=`created: ${a}
`,o+=`updated: ${i}
`,r.length>0&&(o+=`tags: [${r.map(l=>`"${l}"`).join(", ")}]
`),e.source&&(o+=`source: ${e.source}
`),e.originalUrl&&(o+=`url: "${e.originalUrl}"
`),t.distilledNoteId&&(o+=`type: distilled
`,o+=`qualityFlags: [${(t.qualityFlags||[]).map(l=>`"${l}"`).join(", ")}]
`);for(const[l,d]of Object.entries(t))["distilledNoteId","bodyMarkdown","qualityFlags"].includes(l)||(o+=`${l}: ${JSON.stringify(d)}
`);return o+=`---

`,o}function z(e){return e.replace(/[<>:"/\\|?*]/g,"_").replace(/\s+/g,"_").slice(0,100)}function ve(e,t){let r=u.join(e,`${z(t)}.md`);if(!p.existsSync(r))return r;let a=1;for(;p.existsSync(r);)r=u.join(e,`${z(t)}_${a}.md`),a++;return r}async function xe(e,t){try{const r=F(),a=(t==null?void 0:t.vaultPath)||r.vaultPath;if(!a)return{success:!1,error:"Vault path not configured"};if(!p.existsSync(a))return{success:!1,error:"Vault path does not exist"};const i=(t==null?void 0:t.folder)||"Inbox",o=u.join(a,i);p.existsSync(o)||p.mkdirSync(o,{recursive:!0});const l=e.title||`note_${Date.now()}`;let d=ve(o,l);const y=e.metadata||{};let h="";y.bodyMarkdown?h=y.bodyMarkdown:e.previewText?h=e.previewText:e.ocrText?h=e.ocrText:h="（无内容）";let g="";return(t==null?void 0:t.autoFrontmatter)!==!1&&r.autoFrontmatter?g=Ie(e)+h:g=h,p.writeFileSync(d,g,"utf-8"),await x(e.id,{status:"exported",vaultImportPath:d}),n.info("Exported to Obsidian:",d),{success:!0,filePath:d}}catch(r){return n.error("Export failed:",r),{success:!1,error:r instanceof Error?r.message:"Unknown error"}}}async function Ne(){const e=await s.dialog.showOpenDialog({properties:["openDirectory"],title:"选择 Obsidian 仓库"});return e.canceled||e.filePaths.length===0?null:e.filePaths[0]}function Ae(){s.ipcMain.handle("app:getVersion",()=>s.app.getVersion()),s.ipcMain.handle("app:getPlatform",()=>process.platform),s.ipcMain.handle("storage:getSourceItems",(e,t)=>{try{return te(t)}catch(r){throw n.error("storage:getSourceItems failed:",r),r}}),s.ipcMain.handle("storage:getSourceItem",(e,t)=>{try{return I(t)}catch(r){throw n.error("storage:getSourceItem failed:",r),r}}),s.ipcMain.handle("storage:createSourceItem",(e,t)=>{try{return T(t)}catch(r){throw n.error("storage:createSourceItem failed:",r),r}}),s.ipcMain.handle("storage:updateSourceItem",(e,t,r)=>{try{return x(t,r)}catch(a){throw n.error("storage:updateSourceItem failed:",a),a}}),s.ipcMain.handle("storage:deleteSourceItem",(e,t)=>{try{re(t)}catch(r){throw n.error("storage:deleteSourceItem failed:",r),r}}),s.ipcMain.handle("storage:searchSourceItems",(e,t)=>{try{return ae(t)}catch(r){throw n.error("storage:searchSourceItems failed:",r),r}}),s.ipcMain.handle("storage:getStats",()=>{try{return ne()}catch(e){throw n.error("storage:getStats failed:",e),e}}),s.ipcMain.handle("settings:get",()=>{try{return F()}catch(e){throw n.error("settings:get failed:",e),e}}),s.ipcMain.handle("settings:update",(e,t)=>{try{return se(t)}catch(r){throw n.error("settings:update failed:",r),r}}),s.ipcMain.handle("ai:getProviders",()=>j()),s.ipcMain.handle("ai:addProvider",(e,t)=>(Te(t),j())),s.ipcMain.handle("ai:chat",async(e,{providerId:t,messages:r})=>{try{return await R(t,r)}catch(a){throw n.error("ai:chat failed:",a),a}}),s.ipcMain.handle("ai:completion",async(e,{providerId:t,prompt:r})=>{try{return await Ee(t,r)}catch(a){throw n.error("ai:completion failed:",a),a}}),s.ipcMain.handle("distill:item",async(e,t)=>{try{return await B(t)}catch(r){throw n.error("distill:item failed:",r),r}}),s.ipcMain.handle("distill:batch",async(e,t)=>{try{return await _e(t)}catch(r){throw n.error("distill:batch failed:",r),r}}),s.ipcMain.handle("distill:quick",async(e,t)=>{try{return await Se(t)}catch(r){throw n.error("distill:quick failed:",r),r}}),s.ipcMain.handle("export:toObsidian",async(e,t,r)=>{try{const a=I(t);if(!a)throw new Error("Item not found");return await xe(a,r)}catch(a){throw n.error("export:toObsidian failed:",a),a}}),s.ipcMain.handle("export:selectVault",async()=>{try{return await Ne()}catch(e){throw n.error("export:selectVault failed:",e),e}}),s.ipcMain.handle("capture:screenshot",async()=>{try{const e=await ye();return(e==null?void 0:e.dataUrl)||null}catch(e){throw n.error("capture:screenshot failed:",e),e}}),s.ipcMain.handle("capture:screenshotRegion",async()=>new Promise(e=>{we()})),s.ipcMain.handle("capture:selectFile",async()=>{try{const e=await s.dialog.showOpenDialog({properties:["openFile","multiSelections"],filters:[{name:"All Files",extensions:["*"]},{name:"Images",extensions:["png","jpg","jpeg","gif","webp"]},{name:"Documents",extensions:["pdf","docx","doc","txt","md"]}]});return e.canceled?[]:e.filePaths}catch(e){throw n.error("capture:selectFile failed:",e),e}}),s.ipcMain.handle("capture:importFile",async(e,t)=>{try{const r=require("path"),a=r.basename(t),i=r.extname(t).toLowerCase();let o="file";[".png",".jpg",".jpeg",".gif",".webp",".bmp"].includes(i)?o="image":[".pdf"].includes(i)&&(o="pdf");const l=L(void 0,a,t);return T({type:o,source:"file",status:"inbox",title:a,contentPath:l.localPath,previewText:a,tags:[],assetFileIds:[l.id],metadata:{originalPath:t}})}catch(r){throw n.error("capture:importFile failed:",r),r}}),s.ipcMain.handle("capture:captureWebpage",async(e,t)=>{try{return T({type:"webpage",source:"webpage",status:"pending",title:t,previewText:t,originalUrl:t,contentPath:"",tags:[],assetFileIds:[],metadata:{}})}catch(r){throw n.error("capture:captureWebpage failed:",r),r}}),s.ipcMain.handle("clipboard:getStatus",()=>pe()),s.ipcMain.handle("clipboard:toggle",()=>he()),s.ipcMain.handle("clipboard:start",()=>(P(),{watching:!0})),s.ipcMain.handle("clipboard:stop",()=>(C(),{watching:!1})),s.ipcMain.handle("asset:get",(e,t)=>{try{return de(t)}catch{throw new Error("Asset not found")}}),s.ipcMain.handle("asset:readBase64",(e,t)=>{try{return ue(t)}catch{return null}}),n.info("All IPC handlers registered")}n.transports.file.level="info";n.transports.console.level="debug";n.info("AcMind Electron starting...");let c=null,S=null;const V=!s.app.isPackaged;function G(){return n.info("Creating main window..."),c=new s.BrowserWindow({width:1200,height:800,minWidth:900,minHeight:600,title:"AcMind",frame:!0,show:!1,webPreferences:{preload:u.join(__dirname,"../preload/index.js"),nodeIntegration:!1,contextIsolation:!0,sandbox:!1}}),c.on("ready-to-show",()=>{n.info("Main window ready to show"),c==null||c.show()}),c.on("closed",()=>{c=null}),c.on("close",e=>{process.platform==="darwin"&&(e.preventDefault(),c==null||c.hide())}),V?(c.loadURL("http://localhost:5173"),c.webContents.openDevTools()):c.loadFile(u.join(__dirname,"../../dist/index.html")),c}function Me(){const e=V?u.join(__dirname,"../../Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16.png"):u.join(process.resourcesPath,"Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16.png");try{const r=s.nativeImage.createFromPath(e);S=new s.Tray(r.isEmpty()?s.nativeImage.createEmpty():r)}catch{S=new s.Tray(s.nativeImage.createEmpty())}const t=s.Menu.buildFromTemplate([{label:"显示 AcMind",click:()=>c==null?void 0:c.show()},{type:"separator"},{label:"截取屏幕",click:()=>c==null?void 0:c.webContents.send("shortcut:screenshot")},{label:"打开收集箱",click:()=>c==null?void 0:c.show()},{type:"separator"},{label:"退出",click:()=>{s.app.quit()}}]);S.setToolTip("AcMind"),S.setContextMenu(t),S.on("click",()=>c==null?void 0:c.show())}function Oe(){s.globalShortcut.register("CommandOrControl+Shift+A",()=>{n.info("Global shortcut: show AcMind"),c!=null&&c.isVisible()?c.hide():c==null||c.show()}),s.globalShortcut.register("CommandOrControl+Shift+S",()=>{n.info("Global shortcut: screenshot"),c==null||c.webContents.send("shortcut:screenshot")})}async function De(){try{n.info("Initializing storage..."),await Z(),n.info("Storage initialized"),n.info("Initializing asset store..."),await oe(),n.info("Asset store initialized"),n.info("Registering IPC handlers..."),Ae(),n.info("IPC handlers registered"),n.info("Starting clipboard monitor..."),P(),n.info("Clipboard monitor started"),G(),Me(),Oe(),n.info("AcMind Electron initialized successfully")}catch(e){throw n.error("Failed to initialize app:",e),e}}s.app.whenReady().then(De).catch(e=>{n.error("App startup failed:",e),s.app.quit()});s.app.on("window-all-closed",()=>{process.platform!=="darwin"&&s.app.quit()});s.app.on("activate",()=>{c===null?G():c.show()});s.app.on("will-quit",()=>{n.info("App will quit"),s.globalShortcut.unregisterAll(),C(),ie(),ee()});s.app.on("before-quit",()=>{n.info("App before quit")});process.on("uncaughtException",e=>{n.error("Uncaught exception:",e)});process.on("unhandledRejection",e=>{n.error("Unhandled rejection:",e)});
