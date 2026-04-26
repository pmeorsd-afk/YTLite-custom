# YTLite Custom 🎬

**Fork מותאם אישית של YTLite עם מהירות ניגון עד ×10**

---

## 🆕 שינויים מהמקור

| תכונה | מקור | Custom |
|--------|-------|--------|
| מהירות מקסימלית | 5× | **10×** |
| אפשרויות Extra Speed | עד 5.0× | עד 10.0× |
| Default Playback Rate | עד 5.0× | עד 10.0× |
| Hold-to-Speed | עד 5.0× | עד 10.0× |

---

## 🚀 איך לבנות

### 1. העלה ל-GitHub
```bash
git init
git add .
git commit -m "Initial YTLite Custom"
git remote add origin https://github.com/YOUR_USERNAME/YTLite-custom.git
git push -u origin main
```

### 2. הגדר GitHub Secrets
ב-Settings → Secrets and Variables → Actions:
- לא נדרש secrets (הכל פתוח)

### 3. הפעל את ה-Workflow
1. לך ל-GitHub → Actions → **Build YTLite Custom IPA**
2. לחץ **Run workflow**
3. מלא:
   - **ipa_url** — קישור ל-IPA מפוענח של YouTube
   - **tweak_version** — גרסת YTLite (ברירת מחדל: `5.2.1`)
   - **display_name** — שם האפליקציה (ברירת מחדל: `YouTube`)
   - **bundle_id** — Bundle ID (ברירת מחדל: `com.google.ios.youtube`)
4. המתן ~10 דקות — ה-IPA יהיה ב-Releases

---

## 📋 רשימת הטוויקים המלאה

### ⚙️ General
- הסרת פרסומות (`noAds`)
- ניגון ברקע (`backgroundPlayback`)

### 🔝 Navbar
- הסרת Cast / התראות / חיפוש / חיפוש קולי
- Navbar קבוע, הסרת סרגל תת-ניווט, לוגו Premium

### 🎬 Overlay
- הסתרת Autoplay, כתוביות, HUD, כרטיסי סיום
- סרגל התקדמות קבוע, הצגת זמן סיום, פורמט 24 שעות

### ▶️ Player
- מיני-נגן, מסך מלא אנכי, ביטול autoplay
- **מהירות ניגון עד ×10** 🆕
- קו התקדמות אדום, יציאה ממסך מלא בסיום

### 🩳 Shorts
- מצב Shorts בלבד, דילוג אוטומטי, סרגל התקדמות
- הסתרת כל אלמנטי ה-UI של Shorts

### 📱 Tabbar
- הסרת תוויות, אינדיקטורים, לשוניות שונות

### 🔧 Other
- ניהול תגובות/פוסטים, שמירת תמונת פרופיל
- הסרת פריטים מהתפריט הנפתח

---

## ⚠️ הורדת סרטונים/שירים

YTLite **לא כולל** כלי הורדה עצמאי.
- `noPlayerDownloadButton` — רק *מסיר* את כפתור ההורדה של Premium
- להורדה אמיתית יש להוסיף טוויק נפרד כמו **YTDown** או **uYou**

---

## 📝 קרדיטים

- [dayanch96/YTLite](https://github.com/dayanch96/YTLite) — הפרויקט המקורי
