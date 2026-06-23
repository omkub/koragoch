/**
 * 🚀 SysSchool Secure Bridge (Phase 4.5 - FULL GET COMPATIBLE)
 * ระบบเป็นสะพานเชื่อม LINE และจัดการไฟล์รูปภาพ (แก้ปัญหา CORS แบบเบ็ดเสร็จ)
 */

var SECRET_KEY = "RBP_SECURE_2026"; 
var LINE_CHANNEL_TOKEN = "Joa6HALno3QH0RUXzm0ufP562+gbf/Z+PVl2UEsdm+Vh0zaQV9Aykmm5VuExPOI/e/ETRsu8DHLpOiKYcoxmtfi9x+xEoeg40KMHJef5VxhPSp1Ly5CZ7rVFblhjEATm0eJrWiXvuV+SzuelJhQd5QdB04t89/1O/w1cDnyilFU="; 
// Optional debug forwarder only. Leave empty for permanent production use.
// The real LINE webhook URL should be this Apps Script Web App /exec URL.
var DEBUG_WEBHOOK_URL = ""; 
var FIRESTORE_PROJECT_ID = "rbp-chanikarnn";
var FIRESTORE_DATABASE_ID = "school";
var FIREBASE_WEB_API_KEY = "AIzaSyBfTTxNt5EXXPk0w15YlH-EH4c_0sFkLjo";
var DEFAULT_LINE_TARGET_ID = "";

// 📁 ไอดีโฟลเดอร์ Google Drive
var FOLDER_PROFILE_ID = "1Gor8_V0nRjHU5qLYGke4EE86L1c2dB2k"; 
var FOLDER_LEAVE_ID = "1VAtGdnzC18-ixgJomFUsSAKqgZNQ782S"; 

function saveLatestLineIdFromPayload(data) {
  var events = data && data.events ? data.events : [];
  for (var i = 0; i < events.length; i++) {
    var event = events[i] || {};
    var source = event.source || {};
    var latestId = source.groupId || source.roomId || source.userId || "";
    if (latestId) {
      PropertiesService.getScriptProperties().setProperties({
        LATEST_GROUP_ID: latestId,
        LATEST_ID_TIME: new Date().toLocaleString("th-TH"),
        LATEST_SOURCE_TYPE: source.type || "",
        LATEST_WEBHOOK_EVENT_ID: event.webhookEventId || ""
      }, false);
      return latestId;
    }
  }
  return "";
}

// ✨ ฟังก์ชันสำหรับตอบกลับข้อความ LINE 🥇🏆
function replyMessage(replyToken, text) {
  try {
    UrlFetchApp.fetch("https://api.line.me/v2/bot/message/reply", {
      "headers": {
        "Content-Type": "application/json; charset=UTF-8",
        "Authorization": "Bearer " + LINE_CHANNEL_TOKEN,
      },
      "method": "post",
      "payload": JSON.stringify({
        "replyToken": replyToken,
        "messages": [{ "type": "text", "text": text }]
      }),
    });
  } catch (e) {
    console.error("Reply Error: " + e.message);
  }
}

function isLikelyLineTargetId(value) {
  return /^[CUR][0-9a-fA-F]{32,}$/.test((value || "").trim());
}

function readFirestoreStringField(fields, key) {
  var field = fields && fields[key] ? fields[key] : null;
  if (!field) return "";
  return field.stringValue || field.integerValue || field.doubleValue || field.booleanValue || "";
}

function getSavedLineTargetIdFromFirestore() {
  try {
    var url = "https://firestore.googleapis.com/v1/projects/"
      + encodeURIComponent(FIRESTORE_PROJECT_ID)
      + "/databases/"
      + encodeURIComponent(FIRESTORE_DATABASE_ID)
      + "/documents/Settings/line_messaging?key="
      + encodeURIComponent(FIREBASE_WEB_API_KEY);

    var response = UrlFetchApp.fetch(url, {
      method: "get",
      muteHttpExceptions: true
    });

    if (response.getResponseCode() < 200 || response.getResponseCode() >= 300) {
      return "";
    }

    var doc = JSON.parse(response.getContentText());
    var groupId = readFirestoreStringField(doc.fields, "groupId").trim();
    return isLikelyLineTargetId(groupId) ? groupId : "";
  } catch (err) {
    return "";
  }
}

function getLineTargetId() {
  return getSavedLineTargetIdFromFirestore()
    || PropertiesService.getScriptProperties().getProperty("LATEST_GROUP_ID")
    || DEFAULT_LINE_TARGET_ID
    || "";
}

// ==========================================
// 🚀 ขารับข้อมูล (GET) - ปลอดภัยจาก CORS 100%
// ==========================================

function doGet(e) {
  var action = e.parameter.action;
  var secretKey = e.parameter.secretKey;

  if (secretKey !== SECRET_KEY) return createJsonResponse({ status: "error", message: "Invalid Key" }, e);

  // 1. 🕵️‍♂️ ดึงไอดีไลน์ล่าสุด
  if (action === "get_latest_id") {
    var id = getLineTargetId();
    var time = PropertiesService.getScriptProperties().getProperty("LATEST_ID_TIME") || "";
    return createJsonResponse({ status: "success", latestId: id, timestamp: time }, e);
  }

  if (action === "set_latest_id") {
    var manualId = (e.parameter.id || "").trim();
    if (!/^[CUR][0-9a-fA-F]{32,}$/.test(manualId)) {
      return createJsonResponse({ status: "error", message: "Invalid LINE target ID" }, e);
    }
    PropertiesService.getScriptProperties().setProperties({
      LATEST_GROUP_ID: manualId,
      LATEST_ID_TIME: new Date().toLocaleString("th-TH"),
      LATEST_SOURCE_TYPE: "manual"
    }, false);
    return createJsonResponse({ status: "success", latestId: manualId }, e);
  }

  if (action === "debug_latest_id") {
    var props = PropertiesService.getScriptProperties();
    return createJsonResponse({
      status: "success",
      latestId: getLineTargetId(),
      firestoreId: getSavedLineTargetIdFromFirestore() || "",
      latestWebhookId: props.getProperty("LATEST_GROUP_ID") || "",
      fallbackId: DEFAULT_LINE_TARGET_ID || "",
      timestamp: props.getProperty("LATEST_ID_TIME") || "",
      sourceType: props.getProperty("LATEST_SOURCE_TYPE") || "",
      eventId: props.getProperty("LATEST_WEBHOOK_EVENT_ID") || ""
    }, e);
  }

  // 2. 📲 ส่งแจ้งเตือน LINE (ทาง GET เพื่อแก้ปัญหาเว็บบราวเซอร์)
  if (action === "line_notification") {
    var to = e.parameter.to || getLineTargetId();
    var messageText = e.parameter.message; 

    if (!to) return createJsonResponse({ status: "error", message: "Missing LINE target ID" }, e);
    if (!messageText) return createJsonResponse({ status: "error", message: "Missing LINE message" }, e);
    
    try {
      var response = UrlFetchApp.fetch("https://api.line.me/v2/bot/message/push", {
        method: "post",
        muteHttpExceptions: true,
        headers: { 
          "Content-Type": "application/json", 
          "Authorization": "Bearer " + LINE_CHANNEL_TOKEN 
        },
        payload: JSON.stringify({ 
          to: to, 
          messages: [{ type: "text", text: messageText }] 
        })
      });

      var lineStatus = response.getResponseCode();
      var lineBody = response.getContentText();
      
      if (lineStatus >= 200 && lineStatus < 300) {
        return createJsonResponse({ status: "success", lineStatus: lineStatus, result: lineBody }, e);
      } else {
        return createJsonResponse({ status: "error", lineStatus: lineStatus, message: "LINE API Error: " + lineBody }, e);
      }
    } catch (err) {
      return createJsonResponse({ status: "error", message: "Apps Script Internal Error: " + err.toString() }, e);
    }
  }

  return createJsonResponse({ status: "success", message: "Bridge is online (Full GET Mode)" }, e);
}

// ==========================================
// 🚀 ขารับข้อมูล (POST) - สำหรับอัปโหลดไฟล์ (Binary)
// ==========================================

function doPost(e) {
  if (!e || !e.postData || !e.postData.contents) {
    return ContentService.createTextOutput("OK").setMimeType(ContentService.MimeType.TEXT);
  }

  try {
    var data = JSON.parse(e.postData.contents);
    var action = data.action;
    var secretKey = data.secretKey;

    // 🕵️‍♂️ Webhook จาก LINE
    if (!action && data.events) {
      var events = data.events || [];
      var lastId = "";
      for (var i = 0; i < events.length; i++) {
        var event = events[i];
        var id = saveLatestLineIdFromPayload({events: [event]});
        if (id) lastId = id;

        // ✨ ฟีเจอร์ใหม่: ตอบกลับเพื่อบอกไอดีเมื่อพิมพ์คำว่า getid หรือ ขอไอดี ครับ 🥇🏆
        if (event.type === "message" && event.message.type === "text") {
          var userMsg = event.message.text.trim().toLowerCase();
          if (userMsg === "getid" || userMsg === "ขอไอดี") {
            replyMessage(event.replyToken, "🆔 ไอดีของห้องนี้คือ:\n" + id);
          }
        }
      }

      if (events.length > 0 && DEBUG_WEBHOOK_URL) {
        try { UrlFetchApp.fetch(DEBUG_WEBHOOK_URL, { method: "post", contentType: "application/json", payload: JSON.stringify(data) }); } catch(err){}
      }
      return createJsonResponse({ status: "success", latestId: lastId });
    }

    if (secretKey !== SECRET_KEY) return createJsonResponse({ status: "error", message: "Invalid Key" });

    // 📁 คำสั่งอัปโหลดไฟล์ (POST เท่านั้นเพราะไฟล์มีขนาดใหญ่)
    if (action === "upload") {
      var folderId = data.folderId || (data.folderType === "profile" ? FOLDER_PROFILE_ID : FOLDER_LEAVE_ID);
      var folder = DriveApp.getFolderById(folderId);
      var rawFile = data.file64 || data.file || "";
      var base64Data = rawFile.indexOf("base64,") >= 0 ? rawFile.split("base64,").pop() : rawFile;
      var blob = Utilities.newBlob(Utilities.base64Decode(base64Data), data.mimeType, data.name || data.fileName);
      var file = folder.createFile(blob);
      file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW); // 🔓 เปิดแชร์ให้อัตโนมัติครับ
      return createJsonResponse({ status: "success", url: file.getUrl() });
    }

    // 🗑️ คำสั่งลบไฟล์ (รักษาพื้นที่ของไดรฟ์ให้สะอาดอยู่เสมอครับ) 🥇🏆
    if (action === "delete") {
      var fileId = data.fileId;
      if (!fileId) return createJsonResponse({ status: "error", message: "Missing File ID" });
      
      try {
        var file = DriveApp.getFileById(fileId);
        file.setTrashed(true); // 🗑️ ย้ายลงถังขยะครับ (ปลอดภัยกว่าการลบทิ้งทันที)
        return createJsonResponse({ status: "success", message: "File moved to trash" });
      } catch (err) {
        return createJsonResponse({ status: "error", message: "File not found or already deleted" });
      }
    }

    return createJsonResponse({ status: "error", message: "Invalid action" });
  } catch (error) { return createJsonResponse({ status: "error", message: error.toString() }); }
}

function createJsonResponse(data, e) {
  var json = JSON.stringify(data);
  var callback = e && e.parameter && e.parameter.callback;
  if (callback) {
    return ContentService
      .createTextOutput(callback + "(" + json + ");")
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService.createTextOutput(json).setMimeType(ContentService.MimeType.TEXT); 
}
