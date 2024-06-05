<template>
  <v-app>
    <v-app-bar>
      <v-app-bar-title>DropSubs</v-app-bar-title>
    </v-app-bar>
    <v-main>
      <v-btn 
        color="success"
        @click="loadDropbox">
        Reload Files
      </v-btn>
      <v-infinite-scroll
        height="600"
        @load="loadMore"
      >
        <template v-for="(item, index) in items" :key="index">
          <div 
            :class="['pa-2', index % 2 == 0 ? 'bg-grey-lighten-2' : '']"
            >
            <span v-if="item.tag === 'folder'"><v-icon>mdi-folder</v-icon> {{ item.name }}</span>
            <span v-else>{{ item.name }}</span>
          </div>
        </template>
      </v-infinite-scroll>
    </v-main>

    <AppFooter />
  </v-app>
</template>

<script>
import { DROPBOX_ACCESS_TOKEN } from '@/config/config';

export default {
  data: () => ({
    items: [],
  }),

  methods: {
    loadMore({ done }) {
      setTimeout(() => {
        this.items.push(...Array.from({ length: 20 }, (k, v) => v + this.items.at(-1) + 1));
        done('ok');
      }, 1000);
    },
    async loadDropbox() {
      const fetch = await import('isomorphic-fetch');
      const { Dropbox } = await import('dropbox');
      const dbx = new Dropbox({ accessToken: DROPBOX_ACCESS_TOKEN });
      try {
        const response = await dbx.filesListFolder({ path: '' });
        console.log(response);
        this.items = response.result.entries.map(entry => ({
          tag: entry['.tag'],
          name: entry.name
        }));
      } catch (error) {
        console.error(error);
      }
    }
  },

  created() {
    this.loadDropbox();
  }
}
</script>