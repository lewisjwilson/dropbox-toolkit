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
  <draggable
    v-model="items"
    :item-key="'id'"
    :move="checkMove"
    @start="dragging = true"
    @end="dragEnd"
  >
    <template #item="{ element }">
      <div class="list-group-item">
        {{ element.name }}
      </div>
    </template>
  </draggable>
  <div v-if="renameInProgress" class="progress-container">
    <v-progress-circular 
      indeterminate 
      :size="57" 
      :width="7"
      />
  </div>
  <v-infinite-scroll
    v-else
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
import draggable from 'vuedraggable';

export default {
  components: {
    draggable,
  },
  data: () => ({
    items: [],
    totalNumberOfItems: 0,
    accessToken: '',
    currentDirectory: '',
    timestampsLoaded: false,
    renameInProgress: false
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
              this.items = response.result.entries.map((entry, index) => ({
                  id: entry.id,
                  idx: index,
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
            this.items = response.result.entries.map((entry, index) => ({
                id: entry.id,
                idx: index,
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
      this.renameInProgress = true
      this.items.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
      const dbx = new Dropbox({ accessToken: this.accessToken });
      const batchEntries = [];
      const pathMappings = []; // Track original and new paths
      let reportFilePath = "";
      
      this.items.forEach((item, index) => {
        if (item.tag !== 'folder') {
          const pathParts = item.path.split('/');
          const fileNameWithExtension = pathParts.pop();
          const fileNameParts = fileNameWithExtension.split('.');
          const extension = fileNameParts.length > 1 ? fileNameParts.pop() : ''; // Get extension safely
          if (extension === 'txt'){ // skip txt files
            return
          }

          // Set reportFilePath if it's not already set
          if (reportFilePath.length === 0) {
            const directoryPath = pathParts.join('/');
            reportFilePath = directoryPath;
          }

          // Construct the new path
          const newPath = `${pathParts.join('/')}/${index + 1}${extension ? '.' + extension : ''}`;

          batchEntries.push({
            from_path: item.path,
            to_path: newPath,
          });

          pathMappings.push({
            originalPath: item.path,
            newPath: newPath
          });

          // Update local item immediately to reflect the new path
          item.name = `${index + 1}.${extension}`;
          item.path = newPath;
        }
      });

      try {
        const response = await dbx.filesMoveBatchV2({ entries: batchEntries });
        const asyncJobId = response.result.async_job_id;
    
        let jobStatus;
        do {
            await new Promise(resolve => setTimeout(resolve, 2000));
            jobStatus = await dbx.filesMoveBatchCheckV2({ async_job_id: asyncJobId });
        } while (jobStatus.result['.tag'] === 'in_progress');
        
        if (jobStatus.result['.tag'] === 'complete') {
            console.log('All files have been renamed successfully')
            window.alert('All files have been renamed successfully')
        } else {
            console.error('Some files failed to be renamed:', jobStatus.result)
            window.alert('Some files failed to be renamed:', JSON.stringify(jobStatus.result))
        }
      } catch (error) {
        console.error('Error renaming files:', error)
        window.alert('Error renaming files:' + error)
      } finally {
        // Create the content of the .txt file
        let fileContent = 'Original Path -> New Path\n';
        pathMappings.forEach(mapping => {
          fileContent += `${mapping.originalPath} -> ${mapping.newPath}\n`;
        });

        // Generate timestamp for the report filename
        const timestamp = new Date().toISOString().replace(/[-T:]/g, '').slice(0, -5); // Format: YYYYMMDDHHmmss

        // Create a Blob from the file content
        const blob = new Blob([fileContent], { type: 'text/plain' });
        const fileName = `file_rename_report_${timestamp}.txt`;

        // Upload the .txt file to Dropbox
        try {
          const uploadResponse = await dbx.filesUpload({
            path: `${reportFilePath}/${fileName}`,
            contents: blob,
            mode: 'overwrite',
          });
          console.log('Report file uploaded successfully:', uploadResponse)
        } catch (uploadError) {
          console.error('Error uploading report file:', uploadError)
        }
        this.renameInProgress = false
      }
    },

    checkMove(evt) {
      const item = evt.draggedContext.element
      if(item.tag !== 'file') return false // only move file items
      return true;
    },

    dragEnd(evt) {
      this.dragging = false

      console.log(`items before index change:`)
      console.log(this.items)

      const old_idx = evt.oldIndex
      const new_idx = evt.newIndex
      const moved_item = this.items[new_idx]

      console.log('Item being moved:', moved_item);
      console.log('From index:', old_idx);
      console.log('To index:', new_idx);

      this.sortIndexes()

      console.log(`items after index change:`)
      console.log(this.items)
    },

    sortIndexes() {
      this.items = this.items.map((item, index) => ({
        ...item,           // Keep all existing properties of the item
        idx: index         // Set the current position as the index
      }));
    }
  },

  created() {
    this.loadDropbox();
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
.ghost {
  opacity: 0.5;
  background: #c8ebfb;
}
</style>