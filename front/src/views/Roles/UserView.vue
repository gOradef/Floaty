<script>
import choseClass from "@/components/user/choseClass.vue";
import router from "@/router";

export default {
  name: "UserView",
  components: {
    choseClass
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
    })
  },
  methods: {
    returnToClasses() {
      this.chosenClass = {};
      this.isClassChosen = false;
    },
  }
};
</script>

<template>
      <b-card :title="title">
        <choseClass />
      </b-card>
</template>

<style scoped></style>