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
      isClassChosen: false,
      chosenClass: {},
      chosenClassBody: {},

      showForbidden: false,
      hasAccess: true,
      firstLoading: true, // Track loading state
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
      this.hasAccess = await this.$root.$checkAccessRole('teacher');
      if (!this.hasAccess)
        this.showForbidden = true;

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
    <b-row>
      <b-card :title="title">

      <b-col v-if="!isClassChosen && hasAccess">
        <choseClass />
      </b-col>
      <b-col v-else-if="isClassChosen && hasAccess">
        <userForm :classData="chosenClass"/>
      </b-col>
      <b-col v-if="showForbidden">
        <h1>У вас нет доступа к этой странице</h1>
      </b-col>

      </b-card>
    </b-row>
  </b-container>
  </b-overlay>
</template>

<style scoped></style>