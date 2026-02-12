
  const electron = require('electron');
  console.log('typeof electron:', typeof electron);
  console.log('typeof app:', typeof electron.app);
  if (electron.app) {
    electron.app.on('ready', () => {
      console.log('APP READY');
      electron.app.quit();
    });
  } else {
    console.log('electron module returned:', typeof electron === 'string' ? electron : JSON.stringify(Object.keys(electron).slice(0,10)));
    process.exit(1);
  }
