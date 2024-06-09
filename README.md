# DropSubs [incomplete]

A tool to automatically generate english subtitles via the dropbox api and openai's "whisper"

### Prerequisites

- docker

### Setup

#### Dropbox (first time only)
- Create a new app in dropbox and allow it full access to your files.
- Make sure file read and write permissions are set
- Generate an access token

#### Setting Access Tokens within the app (first time only)
- Create the file `.env.local` in the project root directory
- ↓ Paste the following inside the file ↓
```javascript
export const DROPBOX_ACCESS_TOKEN = 'YOUR_ACCESS_TOKEN';
```

#### Starting the App
- Navigate to the root folder of this project in a terminal
- Run the command `docker-compose up`
  
The application will be accessible at [http://localhost:3000](http://localhost:3000)
