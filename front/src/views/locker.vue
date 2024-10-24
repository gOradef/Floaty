<!--
  Should lock chose class, classForm, adminInterface from user without token
-->
<script>
import choseClass from "@/components/user/choseClass.vue";
import userForm from "@/components/user/form.vue";
import AdminView from "@/views/Roles/AdminView.vue";

export default {
  name: "InterfaceLocker",
  components: {
    choseClass,
    userForm,
    AdminView,
  },
  props: {
    compType: {
      type: String,
      required: true,
    } //choseClass, classForm, adminInterface
  },
  data() {
    return {
      interfaces: {
        choseClass: choseClass,
        userForm: userForm,
        AdminView: AdminView,
      },
      roles: {
        choseClass: 'teacher',
        userForm: 'teacher',
        AdminView: 'admin',
      },

      firstLoading: true,
      hasAccess: false,
      noAccessReason: '',

    };
  },
  async mounted() {
    await new Promise(r => setTimeout(r, 600)) //! maybe remove
    try {
      const response = await this.$root.$checkAccessRole(this.roles[this.compType]);
      this.hasAccess = response.status;
      if (!this.hasAccess)
        this.noAccessReason = response.reason;
    } catch (error) {
      console.warn("Error checking access:", error);
      this.hasAccess = false;
    } finally {
      this.firstLoading = false;
    }

    await new Promise(r => setTimeout(r, 100))
    // if (this.hasAccess)
    //   this.$root.$emit('renderContentSection', this.activeSection);

  },
};
</script>

<template>
  <b-overlay :show="firstLoading">
    <b-container
        fluid
    >
      <component v-bind:is="interfaces[compType]" v-if="hasAccess"/>
      <b-col v-if="!hasAccess && !firstLoading" style="min-height: 600px" class=" text-center align-items-center justify-items-center">
        <h1>У вас нет доступа к этой странице.</h1>
        <h3>{{this.noAccessReason}}</h3>
      </b-col>
    </b-container>
  </b-overlay>
</template>

<style scoped>

</style>