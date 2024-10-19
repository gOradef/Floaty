<script>
import choseClass from "@/components/user/choseClass.vue";
import userForm from '@/components/user/form.vue'
import router from "@/router";

export default {
  name: "UserView",
  components: {
    choseClass,
    userForm
  },
  data() {
    return {
      showForbidden: false,
      hasAccess: true,
      firstLoading: true, // Track loading state
      noAccessReason: '',

      isClassChosen: false,
      chosenClass: {},
      chosenClassBody: {},
    };
  },
  computed: {
    title() {
      return (!this.isClassChosen) ? 'Выберите класс' : 'Заполните форму'; // Dynamically compute the title
    },

  },
  async mounted() {
    this.firstLoading = true; // Set loading to true
    await new Promise(r => setTimeout(r, 600))
    try {
      const response = await this.$root.$checkAccessRole('admin');
      this.hasAccess = response.status;
      if (!this.hasAccess)
        this.noAccessReason = response.reason;


    } catch (error) {
      console.error("Error checking access:", error);
      this.hasAccess = false; // Assume no access on error
    } finally {
      this.firstLoading = false; // Set loading to false when done
    }

    this.$root.$on('class:select', (classUUID) => {
      this.chosenClass = classUUID;
      this.isClassChosen = true;

      router.push('/form/' + classUUID.id);
      // this.setBodyOfSelectedClass();
    })
  },
  methods: {
    returnToClasses() {
      this.chosenClass = {};
      this.isClassChosen = false;
    },
    // async setBodyOfSelectedClass() {

    // }
  }
};
</script>

<template>
  <b-overlay :show="firstLoading">
  <b-container
    fluid
    class="d-flex align-items-center justify-content-center min-vh-100 bg-light"
  >
    <b-row v-if="hasAccess">
      <b-card :title="title">

      <b-col v-if="!isClassChosen">
        <choseClass />
      </b-col>
      <b-col v-else-if="isClassChosen">
        <userForm :classData="chosenClass"/>
      </b-col>

      </b-card>
    </b-row>
    <b-col v-if="!hasAccess && !firstLoading" style="min-height: 600px" class=" text-center align-items-center justify-items-center">
      <h1>У вас нет доступа к этой странице.</h1>
      <h3>{{this.noAccessReason}}</h3>
    </b-col>
  </b-container>
  </b-overlay>
</template>

<style scoped></style>