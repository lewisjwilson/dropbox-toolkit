<template>
  <v-app>
    <v-app-bar>
      <v-app-bar-title>DropSubs</v-app-bar-title>
    </v-app-bar>
    <v-main>
      <v-infinite-scroll
        height="fill-height"
        @load="load"
      >
        <template v-for="(item, index) in items" :key="item">
          <div 
            :class="['pa-2', index % 2 == 0 ? 'bg-grey-lighten-2' : '']"
            >
            Item #{{ item }}
          </div>
        </template>
        <template v-slot:load-more="{ props }">
          <v-btn
            icon="mdi-refresh"
            size="small"
            variant="text"
            v-bind="props"
          ></v-btn>
        </template>
      </v-infinite-scroll>
    </v-main>

    <AppFooter />
  </v-app>
</template>

<script>
  export default {
    data: () => ({
      items: Array.from({ length: 50 }, (k, v) => v + 1),
    }),

    methods: {
      load ({ done }) {
        setTimeout(() => {
          this.items.push(...Array.from({ length: 20 }, (k, v) => v + this.items.at(-1) + 1))

          done('ok')
        }, 1000)
      },
      getDropbox() {
        require('isomorphic-fetch'); // or another library of choice.
        var Dropbox = require('dropbox').Dropbox;
        var dbx = new Dropbox({ accessToken: 'YOUR_ACCESS_TOKEN_HERE' });
        dbx.filesListFolder({path: ''})
          .then(function(response) {
            console.log(response);
          })
          .catch(function(error) {
            console.log(error);
          });
      }
    }
  }
</script>
