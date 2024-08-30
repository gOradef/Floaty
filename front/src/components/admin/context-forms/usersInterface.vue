<template>
  <div>
    <div>

    </div>
  </div>
</template>

<script>
  export default {
    name: 'usersInterface',
    props: {
      action: {
        type: String,
        required: true
      },
      entity: {
        type: Object,
        required: true
      }
    },
    data() {
      return {
      //   Region create

      //   Region edit
        /*
        1. rename
        2. [de]grantClass
        3. [de]grantRole
       */

      //   Region grantClassInterface
      //     1. add, remove,
      //
      //   Region resetPassword
      //   Region delete
      }
    },
    beforeMount() {
      this.$root.$off('form:confirm');
    },
    mounted() {
      switch(this.action) {
        case "create":
          this.getOwners();
          this.$root.$on('form:confirm', async () => {
            this.createUser();
          });
          break;
        case "edit":
          this.$root.$on('form:confirm', async () => {
            await this.renameUser();
          });
          break;
        case "reset":
          this.$root.$on('form:confirm', async () => {
            await this.resetPassowrd();
          });
          break;
        case "delete":
          this.$root.$on('form:confirm', async () => {
            await this.deleteUser();
          });
          break;
      }
    },
    methods: {

    },

  }
</script>

<style scoped>

</style>