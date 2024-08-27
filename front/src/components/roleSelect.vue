<script>
import {includes} from "core-js/internals/array-includes";

export default {
  name: "roleSelect",
  data() {
    return {
      userRoles: []
    }
  },
  methods: {
    includes,
    async getRoles() {
      try {
        const res = await this.$makeApiRequest("/api/roles");
        this.userRoles = res.roles;
      }
      catch (error) {
        // Enhanced error logging
        console.error('Failed to fetch user roles:', error); // Log the entire error object
      }
    },
  },
  mounted() {
    this.getRoles();
  },
};
</script>

<template>
  <b-card title="Выберите роль" align="center">
    <b-list-group>
      <b-list-group-item href="/user" :class="{ disabled: !userRoles.includes('teacher') }">
        Классный руководитель
      </b-list-group-item>
      <b-list-group-item href="/org" :class="{ disabled: !userRoles.includes('admin') }"
      > Администратор </b-list-group-item>
    </b-list-group>
  </b-card>
</template>

<style scoped></style>