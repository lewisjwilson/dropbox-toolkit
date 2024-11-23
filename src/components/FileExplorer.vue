<template>
  <v-btn 
    color="success"
    @click="loadDropbox">
    Reload Files
  </v-btn>
  <v-btn 
    :color="[draggableEnabled ? 'red' : 'success']"
    @click="draggableEnabled = !draggableEnabled">
    <span v-if="!draggableEnabled">Enable Reorder</span>
    <span v-else>Disable Reorder</span>
  </v-btn>
  <span class="spacer"> {{ currentDirectory }} </span>
  <v-btn 
    v-if="currentDirectory !== '/' && timestampsLoaded && draggableEnabled"
    class="spacer"
    color="success"
    @click="orderByCaptureDate">
    Order By Capture Date
  </v-btn>
  <v-btn v-if="draggableEnabled"
    color="success"
    @click="confirmRename">
    Save Changes
  </v-btn>
  <div v-if="loading">
    <v-progress-circular
          indeterminate
          color="primary"
          size="24"
          class="mr-2"
    />
    Please wait... This may take a while.
  </div>
  <draggable v-else
    v-model="items"
    :item-key="'id'"
    :move="checkMove"
  >
    <template #item="{ element, index }">
      <div 
        v-if="!element.name.startsWith('.')"
        :class="['draggable-list-item', element.idx % 2 == 0 ? 'bg-grey-lighten-2' : '']"
        @click="selectItem(element)"
        >
        <img v-if="element.thumbnail" :src="`data:image/jpeg;base64,${element.thumbnail}`"  style="width: 100px; height: auto;"/>
        <span v-if="element.tag === 'folder'"><v-icon>mdi-folder</v-icon> {{ element.name }}</span>
        <span v-else class="align-items: center"> {{ element.name }} 
          <span class='sub-element'> ({{ element.createdAt }}) -> {{ index + 1 }}.{{ element.name.includes('.') ? element.name.split('.').pop() : '' }}</span>
        </span>
      </div>
    </template>
  </draggable>
</template>

<script>
import 'isomorphic-fetch'; 
import { Dropbox } from 'dropbox';
import draggable from 'vuedraggable';

export default {
  components: {
    draggable,
  },
  data: () => ({
    savedItemsState: [],
    items: [],
    totalNumberOfItems: 0,
    dbx: null,
    accessToken: '',
    currentDirectory: '',
    timestampsLoaded: false,
    renameInProgress: false,
    draggableEnabled: false,
    loading: true
  }),

  methods: {
    async loadDropbox() {
        this.loading = true
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
              this.dbx = new Dropbox({ accessToken: this.accessToken });

              const response = await this.dbx.filesListFolder({ path: '' });
              this.items = response.result.entries.map((entry, index) => ({
                  id: entry.id,
                  idx: index,
                  tag: entry['.tag'],
                  path: entry.path_display,
                  name: entry.name,
              }))
              this.totalNumberOfItems = this.items.length
              this.savedItemsState = this.items
              await this.getFileMetadata()
              this.loading = false
            } else {
            console.error('Error refreshing Dropbox token:', tokenData);
            }
        } catch (error) {
            console.error('Error fetching data from Dropbox:', error);
        }
    },
    async selectItem(item) {
      if (item.tag === 'folder') {
          this.loading = true
          console.log('Moving to:', item.path);
          this.timestampsLoaded = false
          this.currentDirectory = item.path
          const response = await this.dbx.filesListFolder({ path: item.path });
          this.items = response.result.entries.map((entry, index) => ({
              id: entry.id,
              idx: index + 1,
              tag: entry['.tag'],
              path: entry.path_display,
              name: entry.name,
          }))

          this.totalNumberOfItems = this.items.length
          await this.getFileMetadata()
          this.savedItemsState = this.items
          this.loading = false
      }
    },
    
      async getFileMetadata() {
        const metadataPromises = this.items.map(async item => {
          if (item.tag !== 'folder') {
            const response = await this.dbx.filesGetMetadata({ path: item.path, include_media_info: true });
            if (response.result.media_info && response.result.media_info.metadata) {
              item.createdAt = response.result.media_info.metadata.time_taken
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

      const thumbnailEntries = this.items
        .filter(item => item.tag !== 'folder' && !item.path.endsWith('.txt'))
        .map(item => ({
          path: item.path,
          format: 'jpeg', // Define the format of the thumbnail
          quality: 'quality_80',
          size: 'w128h128', // Define the size (e.g., 128x128)
        }));

      const thumbnailResponseEntries = await this.fetchThumbnailsInChunks(thumbnailEntries);

      thumbnailResponseEntries.forEach((entry, index) => {
        if (entry['.tag'] === 'success') {
          const item = this.items.find(i => i.path === thumbnailEntries[index].path);
          if (item) {
            item.thumbnail = entry.thumbnail; // Set base64 thumbnail data to item
          }
        } else {
          console.error(`Failed to retrieve thumbnail for ${thumbnailEntries[index].path}: ${entry['.tag']}`);
        }
      });

    },

    async fetchThumbnailsInChunks(entries, maxBatchSize = 25) {
      const results = [];
      
      for (let i = 0; i < entries.length; i += maxBatchSize) {
        const chunk = entries.slice(i, i + maxBatchSize);
        
        try {
          const response = await this.dbx.filesGetThumbnailBatch({ entries: chunk });
          results.push(...response.result.entries);
        } catch (error) {
          console.error('Error fetching thumbnails:', error);
        }
      }
      
      return results;
    },

    async orderByCaptureDate() {
      this.renameInProgress = true;
      this.items.sort((a, b) => {
        if (a.tag === 'folder' || b.tag === 'folder') return 0;
        const dateA = a.createdAt ? new Date(a.createdAt) : null;
        const dateB = b.createdAt ? new Date(b.createdAt) : null;

        if (dateA && dateB) {
          return dateA - dateB; // Sort by date if both have `createdAt`
        } 
        if (dateA) {
          return -1; // `a` has a date, so it should come first
        } 
        if (dateB) {
          return 1; // `b` has a date, so it should come first
        }
        return 0; // Neither has a date, keep the order
      });
    },

    async createHistoryFile() {
      let fileContent = 'Original Path, New Path\n'
      const directoryPath = this.items[0].path.split('/').slice(0, -1).join('/')
      let newIndex = 1
      this.items.forEach(newItem => {
        const extension = newItem.path.split('/').pop().split('.').pop()
        if (extension === 'txt' || newItem.tag === 'folder') return
        const oldItem = this.savedItemsState[newItem.idx]
        fileContent += `${oldItem.name}, ${newIndex}\n`
        newItem.idx = newIndex
        newIndex++
      })

      // Create a Blob from the file content
      const blob = new Blob([fileContent], { type: 'text/plain' });
      const fileName = `.filehistory.txt`;

      // Upload the .txt file to Dropbox
      try {
        await this.dbx.filesUpload({
          path: `${directoryPath}/${fileName}`,
          contents: blob,
          mode: 'overwrite',
        })
        this.renameFiles()
      } catch (uploadError) {
        window.alert.error('Error uploading report file')
      }
    },

    async renameFiles() {
      this.loading = true
      const batchEntries = this.items
        .filter(item => item.tag !== 'folder' && !item.path.endsWith('.txt')) // Filter out folders and skip .txt files
        .map(item => {
          item.oldPath = item.path
          const pathParts = item.path.split('/');
          const fileNameWithExtension = pathParts.pop();
          const extension = fileNameWithExtension.split('.').pop();
          const newPath = `${pathParts.join('/')}/${item.idx}.${extension}`;

          return {
            from_path: item.oldPath,
            to_path: newPath
          }
        })
        .filter(entry => entry.from_path !== entry.to_path); // Filter out unchanged paths

      if(!batchEntries) return

      // Send batch move request
      try {
        const batchResponse = await this.dbx.filesMoveBatchV2({
          entries: batchEntries,
          autorename: true // in case of naming conflict
        })

        // Poll for the result until it's complete
        let asyncJobStatus;
        do {
          asyncJobStatus = await this.dbx.filesMoveBatchCheckV2({ async_job_id: batchResponse.result.async_job_id });
          await new Promise(resolve => setTimeout(resolve, 1000)); // Poll every second
        } while (asyncJobStatus.result['.tag'] === 'in_progress');

        // Handle the batch result
        if (asyncJobStatus.result['.tag'] === 'complete') {
          const failedEntries = batchEntries.filter((_, idx) => asyncJobStatus.result.entries[idx]['.tag'] === 'failure');          

          if (failedEntries.length > 0) {
            console.error('Some files failed to be renamed:', failedEntries);
            window.alert('Some files failed to be renamed');
          } else {
            console.log('All files have been renamed successfully');
            window.alert('All files have been renamed successfully');
          }
        } else {
          console.error('Batch move operation failed.');
          window.alert('Batch move operation failed.');
        }
      } catch (error) {
        console.error('Error during batch move:', error);
        window.alert('Error during batch move: ' + error.message);
      } finally {
        await this.reloadCurrentDirectory()
        this.loading = false
      }
    },

    async reloadCurrentDirectory() {
      try {
        const response = await this.dbx.filesListFolder({ path: this.currentDirectory })
        this.items = response.result.entries.map((entry, index) => ({
              id: entry.id,
              idx: index,
              tag: entry['.tag'],
              path: entry.path_display,
              name: entry.name,
          }));
          this.totalNumberOfItems = this.items.length
          await this.getFileMetadata()
          this.savedItemsState = this.items
      } catch (error) {
        console.error('Error loading current folder:', error);
      }
    },

    checkMove(evt) {
      const item = evt.draggedContext.element
      if(item.tag !== 'file' || !this.draggableEnabled) return false // only move file items
      return true
    },

    confirmRename() {
      if (window.confirm("Are you sure?")) {
        // this.createHistoryFile();
        this.renameFiles();
      }
    },

    renameByOrder() {
      this.items
        .slice() // Create a shallow copy to avoid mutating the original array
        .sort((a, b) => a.idx - b.idx) // Sort by `idx` property
        .forEach(item => {
          if(item.tag !== 'file') return
          console.log(item.id + ' → ' + item.name)
          }
        )
      this.sortIndexes()
    },

    sortIndexes() {
      this.items = this.items.map((item, index) => ({
        ...item,           // Keep all existing properties of the item
        idx: index         // Set the current position as the index
      }))
    }
  },

  getFileExtension(fileName) {
    const parts = fileName.split('.')
    return parts.length > 1 ? parts.pop() : '' // Return the last part as extension or empty string if no extension
  },

  created() {
    this.loadDropbox()
  },
}
</script>

<style>
.spacer {
  margin-left: 10px;
}
.progress-container {
  display: flex;
  justify-content: center;
  align-items: center;
}
.draggable-list-item {
  padding: 6px;
  font-size: large;
;
}
.sub-element {
  color: dimgrey;
  font-size: small; 
  font-weight: 500;
}
.ghost {
  opacity: 0.5;
  background: #c8ebfb;
}
</style>