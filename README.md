# Dropbox Toolkit

A tool to perform tasks otherwise not-avaliable via the current dropbox UI

### Current features
- Batch rename all files with a captured date (usu. video files).
  - Chronological rename (1.mp4, 2.mp4... etc)

### Prerequisites
- Docker
- Node v20.14.0
- Dropbox App - created via App Console (file read & write permissions enabled)
- cURL (for Dropbox refresh token)

#### Setting Access Tokens within the app (first time only)
- Create the file `.env.local` in the project root directory
- ↓ Paste the following inside the file ↓
```
VITE_DROPBOX_REFRESH_TOKEN=<YOUR_REFRESH_TOKEN>
VITE_DROPBOX_APP_KEY=<YOUR_APP_KEY>
VITE_DROPBOX_APP_SECRET=<YOUR_APP_SECRET>
```
[How to get Refresh Token](https://nifi.apache.org/docs/nifi-docs/components/org.apache.nifi/nifi-dropbox-services-nar/1.26.0/org.apache.nifi.services.dropbox.StandardDropboxCredentialService/additionalDetails.html) (*Requirement: curl)

#### Starting the App
- Navigate to the root folder of this project in a terminal
- Run the command `docker-compose up`
- Run the command `npm i`
- Run the command `npm run dev`
  
The application will be accessible at [http://localhost:3000](http://localhost:3000)
