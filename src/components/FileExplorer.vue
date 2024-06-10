<template>
  <v-btn 
    color="success"
    @click="loadDropbox">
    Reload Files
  </v-btn>
  <span class="spacer"> {{ currentDirectory }} </span>
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
        <span v-else>{{ item.name }}</span>
      </div>
    </template>
  </v-infinite-scroll>
</template>

<script>
import 'isomorphic-fetch'; 
import { Dropbox } from 'dropbox';

export default {
  data: () => ({
    items: [],
    accessToken: '',
    currentDirectory: ''
  }),

  methods: {
    loadMore({ done }) {
      setTimeout(() => {
        this.items.push(...Array.from({ length: 20 }, (k, v) => v + this.items.at(-1) + 1));
        done('ok');
      }, 1000);
    },
    async loadDropbox() {
        this.currentDirectory = '/'
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
            this.currentDirectory = item.path
            const dbx = new Dropbox({ accessToken: this.accessToken });
            const response = await dbx.filesListFolder({ path: item.path });
            this.items = response.result.entries.map(entry => ({
                tag: entry['.tag'],
                path: entry.path_display,
                name: entry.name,
            }));
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