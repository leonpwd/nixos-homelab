"use strict";

module.exports = {

    // --- CONNEXION PROWLARR ---
    torznab: [
        "http://gluetun:9696/1/api?apikey=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    ],

    // --- CONNEXIONS ARRS ---
    radarr: ["http://radarr:7878?apikey=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
    sonarr: ["http://sonarr:8989?apikey=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],

    // --- CLIENT TORRENT (qBittorrent) ---
    torrentClients: ["qbittorrent:http://admin:adminpassword@gluetun:8080"],
    action: "inject",

    // --- ORGANISATION ---
    addIndexerTag: true,
    linkCategory: "cross-seed",
    searchLimit: 900,

    // --- RECHERCHE & MATCHING ---
    skipRecheck: true,
    useClientTorrents: true, 
    outputDir: null, 
    ignoreTitles: true,
    searchCadence: "1 day",
    excludeRecentSearch: "7 days",
    excludeOlder: "28 days",
    maxDataDepth: 3,
    flatLinking: true,

    // --- RÉPERTOIRES SOURCES ---
    dataDirs: [
        "/HDD1/media/Films",
        "/HDD1/media/Series"
    ],

    // --- LINKING ---
    linkType: "hardlink",
    linkDirs: ["/HDD1/downloads/cross-seed"],

    // --- RECHERCHE & MATCHING ---
    matchMode: "flexible",          // 💡 Permet le matching malgré le renommage Radarr/Sonarr
    fuzzySizeThreshold: 0.02,       // 🔒 Réduit la tolérance à 2% max (évite d'associer 2 releases différentes)
    snatchTimeout: "1 minute",
    searchTimeout: "3 minutes",

    // --- FILTRES ---
    includeNonVideos: true, 
    includeSingleEpisodes: true,
};
