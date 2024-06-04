# DropSubs [incomplete]

A tool to automatically generate english subtitles via the dropbox api and openai's "whisper"

### Prerequisites

- node 20.14.0 (npm)
- vue/cli 5.0.8

### Setup

#### Dropbox (first time only)
- Create a new app in dropbox and allow it full access to your files.
- Make sure file read and write permissions are set
- Generate an access token

#### Setting Access Tokens within the app (first time only)
- Create the file `src/config/config.js`
- ↓ Paste the following inside the file ↓
```javascript
export const DROPBOX_ACCESS_TOKEN = 'YOUR_ACCESS_TOKEN';
```

#### Starting the App
- Navigate to the root folder of this project in a terminal
- Run the command `npm run dev`
  
The application will be accessible at [http://localhost:3000](http://localhost:3000)
