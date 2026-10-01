// Pasteur Meet — copied to ${CONFIG}/web/custom-config.js on VPS (see scripts/install-vps.sh)

config.defaultLanguage = 'fa';
config.disableDeepLinking = true;
config.prejoinPageEnabled = true;
config.enableWelcomePage = false;
config.startWithAudioMuted = false;
config.startWithVideoMuted = false;

// Reduce third-party calls from embedded meet UI
config.disableThirdPartyRequests = true;

// Prefer Persian UI; room/display names still come from JWT / URL
config.useRoomAsSharedDocumentName = false;
