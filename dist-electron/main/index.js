"use strict";const n=require("electron"),d=require("path"),s=require("electron-log"),te=require("better-sqlite3"),p=require("fs"),A=require("crypto");let m=null;const re=`
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
`;function ae(){const e=n.app.getPath("userData");return d.join(e,"acmind.db")}async function ne(){const e=ae(),t=d.dirname(e);p.existsSync(t)||p.mkdirSync(t,{recursive:!0}),s.info(`Opening database at: ${e}`),m=new te(e),m.pragma("journal_mode = WAL"),m.pragma("foreign_keys = ON"),m.exec(re),s.info("Database schema initialized")}function se(){m&&(m.close(),m=null,s.info("Database closed"))}function y(){if(!m)throw new Error("Database not initialized");return m}function F(e){return{id:e.id,type:e.type,source:e.source,status:e.status,title:e.title,contentPath:e.content_path,contentHash:e.content_hash,previewText:e.preview_text,ocrText:e.ocr_text,transcript:e.transcript,polishedTranscript:e.polished_transcript,sourceApp:e.source_app,originalUrl:e.original_url,tags:JSON.parse(e.tags||"[]"),captureItemId:e.capture_item_id,vaultImportPath:e.vault_import_path,assetFileIds:JSON.parse(e.asset_file_ids||"[]"),metadata:JSON.parse(e.metadata||"{}"),createdAt:new Date(e.created_at*1e3),updatedAt:e.updated_at?new Date(e.updated_at*1e3):void 0}}function oe(e){const t=y();let r="SELECT * FROM source_items WHERE 1=1";const a=[];return e!=null&&e.status&&(r+=" AND status = ?",a.push(e.status)),e!=null&&e.type&&(r+=" AND type = ?",a.push(e.type)),e!=null&&e.source&&(r+=" AND source = ?",a.push(e.source)),r+=" ORDER BY created_at DESC",e!=null&&e.limit&&(r+=" LIMIT ?",a.push(e.limit)),e!=null&&e.offset&&(r+=" OFFSET ?",a.push(e.offset)),t.prepare(r).all(...a).map(F)}function I(e){const r=y().prepare("SELECT * FROM source_items WHERE id = ?").get(e);return r?F(r):null}function w(e){const t=y(),r=crypto.randomUUID(),a=Math.floor(Date.now()/1e3);return t.prepare(`
    INSERT INTO source_items (
      id, type, source, status, title, content_path, content_hash,
      preview_text, ocr_text, transcript, polished_transcript,
      source_app, original_url, tags, capture_item_id, vault_import_path,
      asset_file_ids, metadata, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(r,e.type,e.source,e.status,e.title||null,e.contentPath||"",e.contentHash||null,e.previewText||null,e.ocrText||null,e.transcript||null,e.polishedTranscript||null,e.sourceApp||null,e.originalUrl||null,JSON.stringify(e.tags||[]),e.captureItemId||null,e.vaultImportPath||null,JSON.stringify(e.assetFileIds||[]),JSON.stringify(e.metadata||{}),a,a),I(r)}function M(e,t){const r=y(),a=Math.floor(Date.now()/1e3),i=[],o=[];return t.type!==void 0&&(i.push("type = ?"),o.push(t.type)),t.source!==void 0&&(i.push("source = ?"),o.push(t.source)),t.status!==void 0&&(i.push("status = ?"),o.push(t.status)),t.title!==void 0&&(i.push("title = ?"),o.push(t.title)),t.contentPath!==void 0&&(i.push("content_path = ?"),o.push(t.contentPath)),t.previewText!==void 0&&(i.push("preview_text = ?"),o.push(t.previewText)),t.ocrText!==void 0&&(i.push("ocr_text = ?"),o.push(t.ocrText)),t.transcript!==void 0&&(i.push("transcript = ?"),o.push(t.transcript)),t.tags!==void 0&&(i.push("tags = ?"),o.push(JSON.stringify(t.tags))),t.metadata!==void 0&&(i.push("metadata = ?"),o.push(JSON.stringify(t.metadata))),i.push("updated_at = ?"),o.push(a),o.push(e),r.prepare(`UPDATE source_items SET ${i.join(", ")} WHERE id = ?`).run(...o),I(e)}function ie(e){y().prepare("DELETE FROM source_items WHERE id = ?").run(e)}function ce(e){const t=y(),r=`%${e}%`;return t.prepare(`
    SELECT * FROM source_items 
    WHERE title LIKE ? OR preview_text LIKE ? OR ocr_text LIKE ?
    ORDER BY created_at DESC
    LIMIT 50
  `).all(r,r,r).map(F)}function le(){const e=y(),t=e.prepare("SELECT COUNT(*) as count FROM source_items").get().count,r=e.prepare("SELECT COUNT(*) as count FROM source_items WHERE status = 'inbox'").get().count,a=e.prepare("SELECT COUNT(*) as count FROM source_items WHERE status = 'distilled'").get().count,i=e.prepare("SELECT COUNT(*) as count FROM source_items WHERE status = 'exported'").get().count;return{total:t,inbox:r,distilled:a,exported:i}}function D(){const t=y().prepare("SELECT value FROM app_settings WHERE key = 'app_settings'").get();if(t)try{return JSON.parse(t.value)}catch{s.warn("Failed to parse settings, using defaults")}return{theme:"system",language:"zh-CN",vaultPath:"",autoCaptureClipboard:!0,defaultExportTarget:"obsidian",autoFrontmatter:!0,desktopCapsule:{isEnabled:!0,position:"top",autoHide:!0,showVoice:!0,showCapture:!0,showAgent:!0}}}function ue(e){const t=y(),a={...D(),...e};return t.prepare(`
    INSERT OR REPLACE INTO app_settings (key, value) VALUES ('app_settings', ?)
  `).run(JSON.stringify(a)),a}let E=null;function B(){if(!E)throw new Error("Assets database not initialized");return E}async function de(){const e=n.app.getPath("userData"),t=d.join(e,"assets"),r=d.join(e,"assets.db");p.existsSync(t)||p.mkdirSync(t,{recursive:!0}),E=new(require("better-sqlite3"))(r),E.exec(`
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
  `),s.info("AssetStore initialized at:",t)}function pe(){E&&(E.close(),E=null,s.info("AssetStore closed"))}function he(e,t){const r=d.extname(e).toLowerCase();return{".png":"image",".jpg":"image",".jpeg":"image",".gif":"image",".webp":"image",".bmp":"image",".mp3":"audio",".wav":"audio",".m4a":"audio",".aac":"audio",".mp4":"video",".mov":"video",".avi":"video",".mkv":"video",".pdf":"pdf",".docx":"docx",".doc":"docx",".html":"html",".htm":"html",".md":"markdown",".markdown":"markdown"}[r]||"other"}function ge(e){const t=p.readFileSync(e);return A.createHash("sha256").update(t).digest("hex")}function C(e,t,r,a){const i=B(),o=A.randomUUID(),c=n.app.getPath("userData"),u=d.join(c,"assets"),T=d.extname(t),g=`${o}${T}`,f=d.join(u,g);p.copyFileSync(r,f);const X=p.statSync(f),$=he(f),j=ge(f);return i.prepare(`
    INSERT INTO asset_files (id, source_item_id, kind, original_name, local_path, mime_type, size_bytes, sha256)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(o,null,$,t,f,null,X.size,j),{id:o,sourceItemId:e,kind:$,originalName:t,localPath:f,mimeType:a,sizeBytes:X.size,sha256:j,createdAt:new Date}}function fe(e){const r=B().prepare("SELECT * FROM asset_files WHERE id = ?").get(e);return r?{id:r.id,sourceItemId:r.source_item_id,kind:r.kind,originalName:r.original_name,localPath:r.local_path,mimeType:r.mime_type,sizeBytes:r.size_bytes,sha256:r.sha256,createdAt:new Date(r.created_at*1e3),metadata:JSON.parse(r.metadata||"{}")}:null}function me(e){try{const t=p.readFileSync(e),r=d.extname(e).toLowerCase();return`data:${{".png":"image/png",".jpg":"image/jpeg",".jpeg":"image/jpeg",".gif":"image/gif",".webp":"image/webp",".bmp":"image/bmp"}[r]||"application/octet-stream"};base64,${t.toString("base64")}`}catch(t){return s.error("Failed to read asset:",t),null}}let N=null,P="",L="",_=!1;function J(){const e=n.clipboard.readText();return A.createHash("md5").update(e).digest("hex")}function V(){const e=n.clipboard.readImage();if(e.isEmpty())return"";const t=e.toPNG();return A.createHash("md5").update(t).digest("hex")}function R(e=1e3){if(_){s.warn("Clipboard monitor already running");return}P=J(),L=V(),_=!0,s.info("Clipboard monitor started"),N=setInterval(()=>{Te()},e)}function U(){N&&(clearInterval(N),N=null),_=!1,s.info("Clipboard monitor stopped")}function ye(){return{watching:_,interval:_?1e3:0}}function we(){return _?U():R(),{watching:_}}async function Te(){try{const e=J(),t=V();if(e&&e!==P){P=e;const r=n.clipboard.readText();if(r.trim()){const a=r.match(/^https?:\/\/[^\s]+$/);await w({type:a?"webpage":"text",source:"clipboard",status:"inbox",title:r.slice(0,50),previewText:r,originalUrl:a?r:void 0,contentPath:"",tags:[],assetFileIds:[],metadata:{capturedAt:Date.now()}}),z("clipboard:newItem",{type:"text",content:r}),s.info("Clipboard text captured:",r.slice(0,50))}}if(t&&t!==L){L=t;const r=n.clipboard.readImage();if(!r.isEmpty()){const a=r.toPNG(),i=`/tmp/clipboard_${Date.now()}.png`,o=require("fs");o.writeFileSync(i,a);const c=C(void 0,`clipboard_${Date.now()}.png`,i);await w({type:"image",source:"clipboard",status:"inbox",title:`截图 ${new Date().toLocaleString("zh-CN")}`,previewText:"剪贴板图片",contentPath:c.localPath,tags:[],assetFileIds:[c.id],metadata:{capturedAt:Date.now()}}),z("clipboard:newItem",{type:"image",assetId:c.id}),s.info("Clipboard image captured"),o.unlinkSync(i)}}}catch(e){s.error("Clipboard check error:",e)}}function z(e,t){n.BrowserWindow.getAllWindows().forEach(a=>{a.isDestroyed()||a.webContents.send(e,t)})}let b=null;async function be(){try{const e=n.screen.getPrimaryDisplay(),{width:t,height:r}=e.size,a=await n.desktopCapturer.getSources({types:["screen"],thumbnailSize:{width:t,height:r}});return a.length>0?a[0].thumbnail.toDataURL():null}catch(e){return s.error("Full screen capture failed:",e),null}}async function Ee(e){try{const t=n.screen.getPrimaryDisplay(),r=await n.desktopCapturer.getSources({types:["screen"],thumbnailSize:t.size});if(r.length===0)return null;const a=r[0].thumbnail;return a.crop({x:Math.round(e.x*(a.getSize().width/t.size.width)),y:Math.round(e.y*(a.getSize().height/t.size.height)),width:Math.round(e.width*(a.getSize().width/t.size.width)),height:Math.round(e.height*(a.getSize().height/t.size.height))}).toDataURL()}catch(t){return s.error("Region capture failed:",t),null}}async function _e(e){try{const t=e?await Ee(e):await be();if(!t)return null;const r=t.replace(/^data:image\/\w+;base64,/,""),a=Buffer.from(r,"base64"),i=`screenshot_${Date.now()}.png`,o=d.join(n.app.getPath("temp"),i);p.writeFileSync(o,a);const c=C(void 0,i,o);return await w({type:"screenshot",source:"screenshot",status:"captured",title:`截图 ${new Date().toLocaleString("zh-CN")}`,previewText:"屏幕截图",contentPath:c.localPath,tags:[],assetFileIds:[c.id],metadata:{capturedAt:Date.now(),rect:e}}),p.unlinkSync(o),{dataUrl:t,localPath:c.localPath}}catch(t){return s.error("Capture and save failed:",t),null}}function ve(e){b&&b.close();const t=n.screen.getPrimaryDisplay(),{width:r,height:a}=t.bounds;t.scaleFactor,b=new n.BrowserWindow({x:t.bounds.x,y:t.bounds.y,width:r,height:a,frame:!1,transparent:!0,alwaysOnTop:!0,skipTaskbar:!0,resizable:!1,movable:!1,fullscreenable:!1,webPreferences:{nodeIntegration:!1,contextIsolation:!0}}),b.setIgnoreMouseEvents(!1),b.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(`
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
  `)}`),b.on("closed",()=>{b=null})}let v=[{id:"ollama-default",name:"Ollama (本地)",type:"ollama",tier:"local_light",baseUrl:"http://localhost:11434",modelId:"llama3.2",enabled:!0,capabilities:["chat","completion"]}];function q(){return v}function G(e){return v.find(t=>t.id===e)}function O(){return v.find(e=>e.enabled)}function Se(e){const t=v.findIndex(r=>r.id===e.id);t>=0?v[t]=e:v.push(e),s.info("Provider added/updated:",e.id)}async function k(e,t,r){var i;const a=G(e)||O();if(!a)throw new Error("No AI provider available");s.info(`AI chat request to ${a.name} (${a.modelId})`);try{const o=await fetch(`${a.baseUrl}/api/chat`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({model:a.modelId,messages:t.map(c=>({role:c.role,content:c.content})),stream:!!r})});if(!o.ok)throw new Error(`AI request failed: ${o.status}`);if(!r){const c=await o.json();return{content:((i=c.message)==null?void 0:i.content)||"",usage:c.usage,provider:a.name,model:a.modelId}}}catch(o){throw s.error("AI chat error:",o),o}}async function xe(e,t,r){const a=G(e)||O();if(!a)throw new Error("No AI provider available");s.info(`AI completion request to ${a.name} (${a.modelId})`);try{const i=await fetch(`${a.baseUrl}/api/generate`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({model:a.modelId,prompt:t,stream:!!r})});if(!i.ok)throw new Error(`AI request failed: ${i.status}`);if(!r){const o=await i.json();return{content:o.response||"",usage:o.usage,provider:a.name,model:a.modelId}}}catch(i){throw s.error("AI completion error:",i),i}}const Ie=`你是一个知识蒸馏助手。请将用户提供的内容提炼成结构化的笔记。

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

请只输出JSON，不要有其他内容。`;async function K(e){try{const t=I(e);if(!t)return{success:!1,error:"Source item not found"};s.info("Starting distillation for:",t.id),await M(e,{status:"distilling"});const r=t.previewText||t.ocrText||t.transcript||"";if(!r.trim())return{success:!1,error:"No content to distill"};const a=O();if(!a)return{success:!1,error:"No AI provider configured"};const i=[{role:"system",content:Ie},{role:"user",content:`请蒸馏以下内容：

${r}`}],o=await k(a.id,i);let c={};try{const g=o.content.match(/\{[\s\S]*\}/);g&&(c=JSON.parse(g[0]))}catch(g){s.warn("Failed to parse AI response as JSON:",g)}const u={id:crypto.randomUUID(),sourceItemIds:[e],title:c.title||t.title||"无标题",summary:c.summary||"",tags:c.tags||[],suggestedFolder:c.suggestedFolder,bodyMarkdown:c.bodyMarkdown||r,qualityFlags:c.qualityFlags||[],modelProvider:a.name,modelName:a.modelId,reviewStatus:"pending",createdAt:new Date,updatedAt:new Date},T=await w({type:"text",source:"distilled",status:"distilled",title:u.title,previewText:u.summary,contentPath:"",tags:u.tags,assetFileIds:t.assetFileIds,metadata:{distilledNoteId:u.id,bodyMarkdown:u.bodyMarkdown,qualityFlags:u.qualityFlags,modelProvider:u.modelProvider,modelName:u.modelName}});return await M(e,{status:"distilled"}),s.info("Distillation completed:",T.id),{success:!0,distilledNote:{...u,id:T.id}}}catch(t){return s.error("Distillation failed:",t),{success:!1,error:t instanceof Error?t.message:"Unknown error"}}}async function Ne(e){const t=[];for(const r of e){const a=await K(r);t.push(a)}return t}async function Me(e){const t=O();if(!t)throw new Error("No AI provider configured");const r=[{role:"system",content:"你是一个知识提炼助手。请用简洁的语言总结以下内容，突出关键要点。"},{role:"user",content:e}];return(await k(t.id,r)).content}function Ae(e){const t=e.metadata||{},r=e.tags||[],a=new Date(e.createdAt).toISOString().split("T")[0],i=e.updatedAt?new Date(e.updatedAt).toISOString().split("T")[0]:a;let o=`---
`;o+=`title: "${e.title||"无标题"}"
`,o+=`created: ${a}
`,o+=`updated: ${i}
`,r.length>0&&(o+=`tags: [${r.map(c=>`"${c}"`).join(", ")}]
`),e.source&&(o+=`source: ${e.source}
`),e.originalUrl&&(o+=`url: "${e.originalUrl}"
`),t.distilledNoteId&&(o+=`type: distilled
`,o+=`qualityFlags: [${(t.qualityFlags||[]).map(c=>`"${c}"`).join(", ")}]
`);for(const[c,u]of Object.entries(t))["distilledNoteId","bodyMarkdown","qualityFlags"].includes(c)||(o+=`${c}: ${JSON.stringify(u)}
`);return o+=`---

`,o}function H(e){return e.replace(/[<>:"/\\|?*]/g,"_").replace(/\s+/g,"_").slice(0,100)}function De(e,t){let r=d.join(e,`${H(t)}.md`);if(!p.existsSync(r))return r;let a=1;for(;p.existsSync(r);)r=d.join(e,`${H(t)}_${a}.md`),a++;return r}async function Oe(e,t){try{const r=D(),a=(t==null?void 0:t.vaultPath)||r.vaultPath;if(!a)return{success:!1,error:"Vault path not configured"};if(!p.existsSync(a))return{success:!1,error:"Vault path does not exist"};const i=(t==null?void 0:t.folder)||"Inbox",o=d.join(a,i);p.existsSync(o)||p.mkdirSync(o,{recursive:!0});const c=e.title||`note_${Date.now()}`;let u=De(o,c);const T=e.metadata||{};let g="";T.bodyMarkdown?g=T.bodyMarkdown:e.previewText?g=e.previewText:e.ocrText?g=e.ocrText:g="（无内容）";let f="";return(t==null?void 0:t.autoFrontmatter)!==!1&&r.autoFrontmatter?f=Ae(e)+g:f=g,p.writeFileSync(u,f,"utf-8"),await M(e.id,{status:"exported",vaultImportPath:u}),s.info("Exported to Obsidian:",u),{success:!0,filePath:u}}catch(r){return s.error("Export failed:",r),{success:!1,error:r instanceof Error?r.message:"Unknown error"}}}async function Pe(){const e=await n.dialog.showOpenDialog({properties:["openDirectory"],title:"选择 Obsidian 仓库"});return e.canceled||e.filePaths.length===0?null:e.filePaths[0]}let h=null,S=!1;function Le(e){const t=n.screen.getPrimaryDisplay(),{width:r,height:a}=t.workAreaSize,{x:i,y:o}=t.bounds,c=400,u=300;switch(e){case"top":return{x:i+(r-c)/2,y:o};case"bottom":return{x:i+(r-c)/2,y:o+a-u};case"left":return{x:i,y:o+(a-u)/2};case"right":return{x:i+r-c,y:o+(a-u)/2};default:return{x:i+(r-c)/2,y:o}}}function Fe(){if(h)return h;const t=D().desktopCapsule;if(!t.isEnabled)return s.info("Desktop capsule is disabled"),null;const r=Le(t.position),a=400,i=300;return h=new n.BrowserWindow({width:a,height:i,x:r.x,y:r.y,frame:!1,transparent:!0,alwaysOnTop:!0,skipTaskbar:!0,resizable:!1,movable:!0,visible:!t.autoHide,webPreferences:{preload:d.join(__dirname,"../preload/index.js"),nodeIntegration:!1,contextIsolation:!0}}),S=!t.autoHide,h.loadURL("http://localhost:5173/#/capsule"),t.autoHide&&h.setIgnoreMouseEvents(!0),h.on("closed",()=>{h=null,S=!1}),s.info("Capsule window created at:",r),h}function W(){h||Fe(),h&&(h.show(),h.setIgnoreMouseEvents(!1),S=!0,s.info("Capsule shown"))}function Q(){h&&(h.hide(),h.setIgnoreMouseEvents(!0),S=!1,s.info("Capsule hidden"))}function Ce(){S?Q():W()}function Y(){return S}function Re(){n.ipcMain.handle("app:getVersion",()=>n.app.getVersion()),n.ipcMain.handle("app:getPlatform",()=>process.platform),n.ipcMain.handle("storage:getSourceItems",(e,t)=>{try{return oe(t)}catch(r){throw s.error(r),r}}),n.ipcMain.handle("storage:getSourceItem",(e,t)=>{try{return I(t)}catch(r){throw s.error(r),r}}),n.ipcMain.handle("storage:createSourceItem",(e,t)=>{try{return w(t)}catch(r){throw s.error(r),r}}),n.ipcMain.handle("storage:updateSourceItem",(e,t,r)=>{try{return M(t,r)}catch(a){throw s.error(a),a}}),n.ipcMain.handle("storage:deleteSourceItem",(e,t)=>{try{ie(t)}catch(r){throw s.error(r),r}}),n.ipcMain.handle("storage:searchSourceItems",(e,t)=>{try{return ce(t)}catch(r){throw s.error(r),r}}),n.ipcMain.handle("storage:getStats",()=>{try{return le()}catch(e){throw s.error(e),e}}),n.ipcMain.handle("settings:get",()=>{try{return D()}catch(e){throw s.error(e),e}}),n.ipcMain.handle("settings:update",(e,t)=>{try{return ue(t)}catch(r){throw s.error(r),r}}),n.ipcMain.handle("ai:getProviders",()=>q()),n.ipcMain.handle("ai:addProvider",(e,t)=>(Se(t),q())),n.ipcMain.handle("ai:chat",async(e,{providerId:t,messages:r})=>{try{return await k(t,r)}catch(a){throw s.error(a),a}}),n.ipcMain.handle("ai:completion",async(e,{providerId:t,prompt:r})=>{try{return await xe(t,r)}catch(a){throw s.error(a),a}}),n.ipcMain.handle("distill:item",async(e,t)=>{try{return await K(t)}catch(r){throw s.error(r),r}}),n.ipcMain.handle("distill:batch",async(e,t)=>{try{return await Ne(t)}catch(r){throw s.error(r),r}}),n.ipcMain.handle("distill:quick",async(e,t)=>{try{return await Me(t)}catch(r){throw s.error(r),r}}),n.ipcMain.handle("export:toObsidian",async(e,t,r)=>{try{const a=I(t);if(!a)throw new Error("Item not found");return await Oe(a,r)}catch(a){throw s.error(a),a}}),n.ipcMain.handle("export:selectVault",async()=>{try{return await Pe()}catch(e){throw s.error(e),e}}),n.ipcMain.handle("capture:screenshot",async()=>{try{const e=await _e();return(e==null?void 0:e.dataUrl)||null}catch(e){throw s.error(e),e}}),n.ipcMain.handle("capture:screenshotRegion",async()=>new Promise(e=>{ve()})),n.ipcMain.handle("capture:selectFile",async()=>{try{const e=await n.dialog.showOpenDialog({properties:["openFile","multiSelections"],filters:[{name:"All Files",extensions:["*"]},{name:"Images",extensions:["png","jpg","jpeg","gif","webp"]},{name:"Documents",extensions:["pdf","docx","doc","txt","md"]}]});return e.canceled?[]:e.filePaths}catch(e){throw s.error(e),e}}),n.ipcMain.handle("capture:importFile",async(e,t)=>{try{const r=require("path"),a=r.basename(t),i=r.extname(t).toLowerCase();let o="file";[".png",".jpg",".jpeg",".gif",".webp",".bmp"].includes(i)?o="image":[".pdf"].includes(i)&&(o="pdf");const c=C(void 0,a,t);return w({type:o,source:"file",status:"inbox",title:a,contentPath:c.localPath,previewText:a,tags:[],assetFileIds:[c.id],metadata:{originalPath:t}})}catch(r){throw s.error(r),r}}),n.ipcMain.handle("capture:captureWebpage",async(e,t)=>{try{return w({type:"webpage",source:"webpage",status:"pending",title:t,previewText:t,originalUrl:t,contentPath:"",tags:[],assetFileIds:[],metadata:{}})}catch(r){throw s.error(r),r}}),n.ipcMain.handle("clipboard:getStatus",()=>ye()),n.ipcMain.handle("clipboard:toggle",()=>we()),n.ipcMain.handle("clipboard:start",()=>(R(),{watching:!0})),n.ipcMain.handle("clipboard:stop",()=>(U(),{watching:!1})),n.ipcMain.handle("capsule:show",()=>(W(),{visible:!0})),n.ipcMain.handle("capsule:hide",()=>(Q(),{visible:!1})),n.ipcMain.handle("capsule:toggle",()=>(Ce(),{visible:Y()})),n.ipcMain.handle("capsule:isVisible",()=>({visible:Y()})),n.ipcMain.handle("asset:get",(e,t)=>{try{return fe(t)}catch{throw new Error("Asset not found")}}),n.ipcMain.handle("asset:readBase64",(e,t)=>{try{return me(t)}catch{return null}}),n.ipcMain.handle("quicknote:add",async(e,t)=>{try{return w({type:"text",source:"manual",status:"inbox",title:t.slice(0,50),previewText:t,contentPath:"",tags:["quicknote"],assetFileIds:[],metadata:{}})}catch(r){throw s.error(r),r}}),s.info("All IPC handlers registered")}s.transports.file.level="info";s.transports.console.level="debug";s.info("AcMind Electron starting...");let l=null,x=null;const Z=!n.app.isPackaged;function ee(){return s.info("Creating main window..."),l=new n.BrowserWindow({width:1200,height:800,minWidth:900,minHeight:600,title:"AcMind",frame:!0,show:!1,webPreferences:{preload:d.join(__dirname,"../preload/index.js"),nodeIntegration:!1,contextIsolation:!0,sandbox:!1}}),l.on("ready-to-show",()=>{s.info("Main window ready to show"),l==null||l.show()}),l.on("closed",()=>{l=null}),l.on("close",e=>{process.platform==="darwin"&&(e.preventDefault(),l==null||l.hide())}),Z?(l.loadURL("http://localhost:5173"),l.webContents.openDevTools()):l.loadFile(d.join(__dirname,"../../dist/index.html")),l}function Ue(){const e=Z?d.join(__dirname,"../../Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16.png"):d.join(process.resourcesPath,"Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16.png");try{const r=n.nativeImage.createFromPath(e);x=new n.Tray(r.isEmpty()?n.nativeImage.createEmpty():r)}catch{x=new n.Tray(n.nativeImage.createEmpty())}const t=n.Menu.buildFromTemplate([{label:"显示 AcMind",click:()=>l==null?void 0:l.show()},{type:"separator"},{label:"截取屏幕",click:()=>l==null?void 0:l.webContents.send("shortcut:screenshot")},{label:"打开收集箱",click:()=>l==null?void 0:l.show()},{type:"separator"},{label:"退出",click:()=>{n.app.quit()}}]);x.setToolTip("AcMind"),x.setContextMenu(t),x.on("click",()=>l==null?void 0:l.show())}function ke(){n.globalShortcut.register("CommandOrControl+Shift+A",()=>{s.info("Global shortcut: show AcMind"),l!=null&&l.isVisible()?l.hide():l==null||l.show()}),n.globalShortcut.register("CommandOrControl+Shift+S",()=>{s.info("Global shortcut: screenshot"),l==null||l.webContents.send("shortcut:screenshot")})}async function Xe(){try{s.info("Initializing storage..."),await ne(),s.info("Storage initialized"),s.info("Initializing asset store..."),await de(),s.info("Asset store initialized"),s.info("Registering IPC handlers..."),Re(),s.info("IPC handlers registered"),s.info("Starting clipboard monitor..."),R(),s.info("Clipboard monitor started"),ee(),Ue(),ke(),s.info("AcMind Electron initialized successfully")}catch(e){throw s.error("Failed to initialize app:",e),e}}n.app.whenReady().then(Xe).catch(e=>{s.error("App startup failed:",e),n.app.quit()});n.app.on("window-all-closed",()=>{process.platform!=="darwin"&&n.app.quit()});n.app.on("activate",()=>{l===null?ee():l.show()});n.app.on("will-quit",()=>{s.info("App will quit"),n.globalShortcut.unregisterAll(),U(),pe(),se()});n.app.on("before-quit",()=>{s.info("App before quit")});process.on("uncaughtException",e=>{s.error("Uncaught exception:",e)});process.on("unhandledRejection",e=>{s.error("Unhandled rejection:",e)});
