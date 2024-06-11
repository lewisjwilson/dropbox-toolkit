<template>
  <v-btn 
    color="success"
    @click="loadDropbox">
    Reload Files
  </v-btn>
  <span class="spacer"> {{ currentDirectory }} </span>
  <v-btn 
    v-if="currentDirectory !== '/' && timestampsLoaded"
    class="spacer"
    color="success"
    @click="confirmRenameByCaptureDate">
    Rename By Capture Date
  </v-btn>
  <v-infinite-scroll
    height="600"
    @load="loadMore"
  >
    <template v-for="(item, index) in items" :key="index">
      <div 
        :class="['pa-2', index % 2 == 0 ? 'bg-grey-lighten-2' : '']"
        @click="selectItem(item)"
        >
        <span v-if="item.tag === 'folder'"><v-icon>mdi-folder</v-icon> {{ item.name }}</span>
        <span v-else>{{ item.name }} <span style="font-size: x-small; font-weight: 500">{{ item.createdAt }}</span> </span>
      </div>
    </template>
    <template v-slot:empty>
    </template>
  </v-infinite-scroll>
</template>

<script>
import 'isomorphic-fetch'; 
import { Dropbox } from 'dropbox';

export default {
  data: () => ({
    items: [],
    totalNumberOfItems: 0,
    accessToken: '',
    currentDirectory: '',
    timestampsLoaded: false
  }),

  methods: {
    loadMore({ done }) {
      setTimeout(() => {
        const currentItemCount = this.items.length;
        const itemsToLoad = 20;
        const remainingItems = this.totalNumberOfItems - currentItemCount;
        const itemsToAdd = Math.min(itemsToLoad, remainingItems);
        
        if (itemsToAdd > 0) {
          this.items.push(...Array.from({ length: itemsToAdd }, (v, k) => k + currentItemCount + 1));
          done('ok');
        } else {
          done('empty');
        }
      }, 1000);
    },
    async loadDropbox() {
        this.currentDirectory = '/'
        this.timestampsLoaded = false
        const refreshToken = import.meta.env.VITE_DROPBOX_REFRESH_TOKEN;
        const clientId = import.meta.env.VITE_DROPBOX_APP_KEY;
        const clientSecret = import.meta.env.VITE_DROPBOX_APP_SECRET;

        if (!refreshToken || !clientId || !clientSecret) {
            console.error('Dropbox credentials are missing.');
            console.log('Refresh Token:', refreshToken);
            console.log('Client ID:', clientId);
            console.log('Client Secret:', clientSecret);
            return;
        }

        try {
            const tokenResponse = await fetch('https://api.dropbox.com/oauth2/token', {
              method: 'POST',
              headers: {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'Authorization': 'Basic ' + btoa(clientId + ':' + clientSecret),
              },
              body: new URLSearchParams({
                  grant_type: 'refresh_token',
                  refresh_token: refreshToken,
              }),
            });

            const tokenData = await tokenResponse.json();

            if (tokenResponse.ok) {
              this.accessToken = tokenData.access_token;
              const dbx = new Dropbox({ accessToken: this.accessToken });

              const response = await dbx.filesListFolder({ path: '' });
              this.items = response.result.entries.map(entry => ({
                  tag: entry['.tag'],
                  path: entry.path_display,
                  name: entry.name,
              }));
              this.totalNumberOfItems = this.items.length
              this.getFileMetadata()
            } else {
            console.error('Error refreshing Dropbox token:', tokenData);
            }
        } catch (error) {
            console.error('Error fetching data from Dropbox:', error);
        }
    },
    async selectItem(item) {
        if (item.tag === 'folder') {
            console.log('Moving to:', item.path);
            this.timestampsLoaded = false
            this.currentDirectory = item.path
            const dbx = new Dropbox({ accessToken: this.accessToken });
            const response = await dbx.filesListFolder({ path: item.path });
            this.items = response.result.entries.map(entry => ({
                tag: entry['.tag'],
                path: entry.path_display,
                name: entry.name,
            }));
            this.totalNumberOfItems = this.items.length
            this.getFileMetadata()
        }
    },
    
    async getFileMetadata() {
      const dbx = new Dropbox({ accessToken: this.accessToken });
      const metadataPromises = this.items.map(async item => {
        if (item.tag !== 'folder') {
          const response = await dbx.filesGetMetadata({ path: item.path, include_media_info: true });
          if (response.result.media_info && response.result.media_info.metadata) {
            item.createdAt = response.result.media_info.metadata.time_taken;
          }
        }
      });
      await Promise.all(metadataPromises)
      .then(() => {
        this.timestampsLoaded = true
      })
      .catch(error => {
        console.error('Error fetching metadata:', error);
      });
    },

    confirmRenameByCaptureDate() {
      if (window.confirm("Are you sure you want to rename files by capture date?")) {
        this.renameByCaptureDate();
      }
    },

    async renameByCaptureDate() {
      this.items.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
      const dbx = new Dropbox({ accessToken: this.accessToken });
      const batchEntries = [];
      this.items.forEach((item, index) => {
        if (item.tag !== 'folder') {
          const path = item.path.split('/');
          const fileNameWithExtension = path.pop();
          const extension = fileNameWithExtension.split('.')[1];
          const newPath = `${item.path.substring(0, item.path.lastIndexOf('/') + 1)}${index + 1}.${extension}`;

          batchEntries.push({
            from_path: item.path,
            to_path: newPath,
          });

          // Update local item immediately to reflect the new path
          item.name = `${index + 1}.${extension}`;
          item.path = newPath;
        }
      });

      try {
        const response = await dbx.filesMoveBatchV2({ entries: batchEntries });
      } catch (error) {
        console.error('Error renaming files:', error);
      }
    }
  },

  created() {
    this.loadDropbox();
  }
}
</script>

<style>
.spacer {
  margin-left: 10px;
}
</style>