/* =============================================================================
 * MagicMirror² Configuration — Endurance Home Server
 * =============================================================================
 * Modules:
 *   • Clock       — Local time and date
 *   • Calendar    — iCloud calendar via ICS URL
 *   • Weather     — Current conditions + forecast (OpenWeatherMap)
 *   • Compliments — Random compliments / motivational phrases
 *   • News Feed   — RSS headlines
 *
 * SETUP INSTRUCTIONS:
 *   1. Replace YOUR_OPENWEATHERMAP_API_KEY with a free key from:
 *      https://openweathermap.org/api  (sign up → API keys)
 *
 *   2. Replace YOUR_ICAL_URL with your iCloud calendar ICS URL:
 *      - Go to icloud.com → Calendar
 *      - Click the share icon next to a calendar
 *      - Enable "Public Calendar" and copy the URL
 *      - The URL looks like: https://p*-caldav.icloud.com/published/2/...
 *
 *   3. Adjust latitude/longitude for your location.
 *
 *   4. Restart the module: ./provisioning/scripts/module.sh magicmirror restart
 * ========================================================================== */

let config = {
  address: "0.0.0.0",     // Listen on all interfaces (LAN access)
  port: 8080,
  basePath: "/",
  ipWhitelist: [],         // Allow all IPs on LAN (restrict if needed)

  language: "en",
  locale: "en-US",
  timeFormat: 24,
  units: "metric",

  modules: [
    // ─── Clock ──────────────────────────────────────────────────
    {
      module: "clock",
      position: "top_left",
      config: {
        timeFormat: 24,
        showDate: true,
        showWeek: true,
        dateFormat: "dddd, D MMMM YYYY",
      },
    },

    // ─── Calendar (iCloud via ICS) ──────────────────────────────
    // INSTRUCTIONS:
    //   Replace the URL below with your iCloud public calendar ICS URL.
    //   You can add multiple calendars by adding more entries to the
    //   "calendars" array.
    {
      module: "calendar",
      header: "Calendar",
      position: "top_left",
      config: {
        maximumEntries: 10,
        maximumNumberOfDays: 14,
        fetchInterval: 300000,    // 5 minutes
        calendars: [
          {
            // ╔═══════════════════════════════════════════════════════╗
            // ║  CHANGE THIS: Your iCloud public calendar ICS URL    ║
            // ╚═══════════════════════════════════════════════════════╝
            fetchInterval: 300000,
            symbol: "calendar-check",
            url: "YOUR_ICAL_URL",
            // Example:
            // url: "https://p74-caldav.icloud.com/published/2/MTIzNDU2Nzg5...",
          },
          // Add more calendars here:
          // {
          //   symbol: "calendar",
          //   url: "https://another-calendar-url.ics",
          //   color: "#e06c75",
          // },
        ],
      },
    },

    // ─── Current Weather ────────────────────────────────────────
    // INSTRUCTIONS:
    //   1. Get a free API key at https://openweathermap.org/api
    //   2. Replace YOUR_OPENWEATHERMAP_API_KEY below
    //   3. Set your city coordinates (lat/lon)
    {
      module: "weather",
      position: "top_right",
      config: {
        weatherProvider: "openweathermap",
        type: "current",
        // ╔═══════════════════════════════════════════════════════╗
        // ║  CHANGE THIS: Your OpenWeatherMap API key            ║
        // ╚═══════════════════════════════════════════════════════╝
        apiKey: "YOUR_OPENWEATHERMAP_API_KEY",
        // ╔═══════════════════════════════════════════════════════╗
        // ║  CHANGE THIS: Your city coordinates                  ║
        // ║  Find yours at: https://www.latlong.net              ║
        // ╚═══════════════════════════════════════════════════════╝
        lat: 40.4168,       // Madrid, Spain (example)
        lon: -3.7038,
        units: "metric",
        showHumidity: true,
        showWindSpeed: true,
      },
    },

    // ─── Weather Forecast ───────────────────────────────────────
    {
      module: "weather",
      position: "top_right",
      header: "Forecast",
      config: {
        weatherProvider: "openweathermap",
        type: "forecast",
        apiKey: "YOUR_OPENWEATHERMAP_API_KEY",   // Same key as above
        lat: 40.4168,
        lon: -3.7038,
        units: "metric",
        maxNumberOfDays: 5,
      },
    },

    // ─── Compliments ────────────────────────────────────────────
    {
      module: "compliments",
      position: "lower_third",
      config: {
        compliments: {
          anytime: [
            "Welcome home",
            "Looking sharp!",
            "Systems nominal",
          ],
          morning: [
            "Good morning!",
            "Rise and shine",
          ],
          afternoon: [
            "Good afternoon",
            "Keep up the great work",
          ],
          evening: [
            "Good evening",
            "Time to relax",
          ],
        },
      },
    },

    // ─── News Headlines ─────────────────────────────────────────
    {
      module: "newsfeed",
      position: "bottom_bar",
      config: {
        feeds: [
          {
            title: "BBC News",
            url: "https://feeds.bbci.co.uk/news/technology/rss.xml",
          },
        ],
        showSourceTitle: true,
        showPublishDate: true,
        broadcastNewsFeeds: true,
        broadcastNewsUpdates: true,
        maxNewsItems: 5,
      },
    },
  ],
};

/*************** DO NOT EDIT THE LINE BELOW ***************/
if (typeof module !== "undefined") {
  module.exports = config;
}
