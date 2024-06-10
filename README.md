# DropSubs [incomplete]

A tool to automatically generate english subtitles via the dropbox api and openai's "whisper"

### Prerequisites

- Docker
- Dropbox App - created via App Console (file read & write persmissions enabled)

#### Setting Access Tokens within the app (first time only)
- Create the file `.env.local` in the project root directory
- ↓ Paste the following inside the file ↓
```javascript
VITE_DROPBOX_REFRESH_TOKEN=<YOUR_REFRESH_TOKEN>
VITE_DROPBOX_APP_KEY=<YOUR_APP_KEY>
VITE_DROPBOX_APP_SECRET=<YOUR_APP_SECRET>
```
[How to get Refresh Token](https://nifi.apache.org/docs/nifi-docs/components/org.apache.nifi/nifi-dropbox-services-nar/1.26.0/org.apache.nifi.services.dropbox.StandardDropboxCredentialService/additionalDetails.html) (*Requirement: curl)

#### Starting the App
- Navigate to the root folder of this project in a terminal
- Run the command `docker-compose up`
  
The application will be accessible at [http://localhost:3000](http://localhost:3000)
