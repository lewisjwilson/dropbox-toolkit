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
    @click="confirmOrderByCaptureDate">
    Order By Capture Date
  </v-btn>
  <v-btn v-if="draggableEnabled"
    color="success"
    @click="confirmRename">
    Save Changes
  </v-btn>
  <draggable
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

        <span v-if="element.tag === 'folder'"><v-icon>mdi-folder</v-icon> {{ element.name }}</span>
        <span v-else> {{ element.name }} 
          <span class='sub-element'> -> {{ index }}.{{ element.name.includes('.') ? element.name.split('.').pop() : '' }}</span>
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
    accessToken: '',
    currentDirectory: '',
    timestampsLoaded: false,
    renameInProgress: false,
    draggableEnabled: false
  }),

  methods: {
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
              }))
              this.totalNumberOfItems = this.items.length
              this.savedItemsState = this.items
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
            this.savedItemsState = this.items
            
            console.log(this.items)
        }
    },
    
    async getFileMetadata() {
      const dbx = new Dropbox({ accessToken: this.accessToken });
      const metadataPromises = this.items.map(async item => {
        if (item.tag !== 'folder') {
          const response = await dbx.filesGetMetadata({ path: item.path, include_media_info: true });
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
    },

    async createThumbnailFromBlob(blob) {
      return URL.createObjectURL(blob)
    },

    confirmOrderByCaptureDate() {
      if (window.confirm("Are you sure you want to order files by capture date?")) {
        this.orderByCaptureDate();
      }
    },

    async orderByCaptureDate() {
      this.renameInProgress = true
      this.items.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt))
    },

    async createHistoryFile() {
      const dbx = new Dropbox({ accessToken: this.accessToken });
      let fileContent = 'Original Path, New Path\n'
      const directoryPath = this.items[0].path.split('/').slice(0, -1).join('/')
      let newIndex = 0
      this.items.forEach(newItem => {
        const extension = newItem.path.split('/').pop().split('.').pop()
        if (extension === 'txt' || newItem.tag === 'folder') return
        const oldItem = this.savedItemsState[newItem.idx]
        fileContent += `${oldItem.name}, ${newIndex}\n`
        newItem.idx = newIndex
        newIndex++
      })

      // Generate timestamp for the report filename
      const timestamp = new Date().toISOString().replace(/[-T:]/g, '').slice(0, -5); // Format: YYYYMMDDHHmmss

      // Create a Blob from the file content
      const blob = new Blob([fileContent], { type: 'text/plain' });
      const fileName = `filehistory_${timestamp}.txt`;

      // Upload the .txt file to Dropbox
      try {
        await dbx.filesUpload({
          path: `${directoryPath}/.${fileName}`,
          contents: blob,
          mode: 'overwrite',
        })
        this.renameFiles()
      } catch (uploadError) {
        window.alert.error('Error uploading report file')
      }
    },

    async renameFiles() {
      const dbx = new Dropbox({ accessToken: this.accessToken });
      
      const batchEntries = this.items
        .filter(item => item.tag !== 'folder' && !item.path.endsWith('.txt')) // Filter out folders and skip .txt files
        .map(item => {
          item.oldPath = item.path
          const pathParts = item.path.split('/');
          const fileNameWithExtension = pathParts.pop();
          const extension = fileNameWithExtension.split('.').pop();
          const newPath = `${pathParts.join('/')}/temp/${item.idx}.${extension}`;

          // Set the destination path in the temp subfolder
          return {
            from_path: item.oldPath,
            to_path: newPath
          }
        })

      if(!batchEntries) return

      // Define `temp` folder path
      const tempFolderPath = `${batchEntries[0].to_path.split('/').slice(0, -1).join('/')}`;
      try {
        await dbx.filesCreateFolderV2({ path: tempFolderPath });
        console.log(`Created folder: ${tempFolderPath}`);
      } catch (error) {
        if (error.status !== 409) { // Ignore 'already exists' error
          console.error(`Failed to create folder: ${tempFolderPath}`, error);
          throw error;
        }
      }

      // Send batch copy request
      try {
        const batchResponse = await dbx.filesCopyBatchV2({
          entries: batchEntries
        });

        // Poll for the result until it's complete
        let asyncJobStatus;
        do {
          asyncJobStatus = await dbx.filesCopyBatchCheckV2({ async_job_id: batchResponse.result.async_job_id });
          await new Promise(resolve => setTimeout(resolve, 1000)); // Poll every second
        } while (asyncJobStatus.result['.tag'] === 'in_progress');

        // Handle the batch result
        if (asyncJobStatus.result['.tag'] === 'complete') {
          const failedEntries = batchEntries.filter((_, idx) => asyncJobStatus.result.entries[idx]['.tag'] === 'failure');          

          if (failedEntries.length > 0) {
            console.error('Some files failed to be copied:', failedEntries);
            window.alert('Some files failed to be copied. Reverting changes.');
            
          } else {
            console.log('All files have been copied to /temp successfully');
            window.alert('All files have been copied to /temp successfully');
            await this.moveFilesFromTemp(batchEntries, tempFolderPath)
          }
        } else {
          console.error('Batch copy operation failed.');
          window.alert('Batch copy operation failed.');
        }
      } catch (error) {
        console.error('Error during batch copy:', error);
        window.alert('Error during batch copy: ' + error.message);
      }
    },

    async moveFilesFromTemp(batchEntries, tempFolderPath) {
      const dbx = new Dropbox({ accessToken: this.accessToken });
      const deleteEntries = batchEntries.map(entry => ({ path: entry.from_path }));

      // Perform the batch delete
      const deleteResponse = await dbx.filesDeleteBatch({ entries: deleteEntries });

      // Poll until batch delete is complete
      let deleteJobStatus;
      do {
        deleteJobStatus = await dbx.filesDeleteBatchCheck({ async_job_id: deleteResponse.result.async_job_id });
        await new Promise(resolve => setTimeout(resolve, 1000)); // Poll every second
      } while (deleteJobStatus.result['.tag'] === 'in_progress');

      if (deleteJobStatus.result['.tag'] === 'complete') {
        console.log('All original files have been deleted successfully.');
        window.alert('Files have been copied and original files deleted.');
      } else {
        console.error('Batch delete operation failed.');
        window.alert('Batch delete operation failed.');
        return
      }

      const moveBackEntries = batchEntries.map(entry => {
        const tempPathParts = entry.to_path.split('/');
        const fileName = tempPathParts.pop(); // Extract the filename with extension
        tempPathParts.splice(-1, 1); // Remove `temp` from the path to move up one level

        return {
          from_path: entry.to_path,
          to_path: `${tempPathParts.join('/')}/${fileName}`, // Reconstruct the path without `temp`
        };
      });

      // Perform the batch move from `temp` to the parent folder
      const moveResponse = await dbx.filesMoveBatchV2({ entries: moveBackEntries });

      // Poll until batch move is complete
      let moveJobStatus;
      do {
        moveJobStatus = await dbx.filesMoveBatchCheckV2({ async_job_id: moveResponse.result.async_job_id });
        await new Promise(resolve => setTimeout(resolve, 1000)); // Poll every second
      } while (moveJobStatus.result['.tag'] === 'in_progress');

      if (moveJobStatus.result['.tag'] === 'complete') {
        console.log('All files have been moved back up one level successfully.');
        window.alert('Files have been successfully moved up one level.');
        this.deleteTempFolder(tempFolderPath)
      } else {
        console.error('Batch move operation failed.');
        window.alert('Batch move operation failed.');
      }
    },

    async deleteTempFolder(path) {
      const dbx = new Dropbox({ accessToken: this.accessToken });
      try {
        await dbx.filesDeleteV2({ path: path });
        console.log(`Deleted temp folder and its contents: ${path}`);
      } catch (deleteError) {
        console.error(`Failed to delete temp folder: ${path}`, deleteError);
      }
    },

    checkMove(evt) {
      const item = evt.draggedContext.element
      if(item.tag !== 'file' || !this.draggableEnabled) return false // only move file items
      return true
    },

    confirmRename() {
      if (window.confirm("Are you sure?")) {
        this.createHistoryFile();
      }
    },

    renameByOrder() {
      console.log(`items before index change:`)
      this.items
        .slice() // Create a shallow copy to avoid mutating the original array
        .sort((a, b) => a.idx - b.idx) // Sort by `idx` property
        .forEach(item => {
          if(item.tag !== 'file') return
          console.log(item.id + ' → ' + item.name)
          }
        )
;
        
      this.sortIndexes()

      console.log(`items after index change:`)
      console.log(this.items)
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