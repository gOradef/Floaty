<template>
  <b-col class="sidebar">
    <h2>Разделы</h2>
    <b-list-group>
      <b-list-group-item
          v-for="section in sections"
          :key="section.value"
          :class="{ active: activeSection === section.value }"
          @click="handleClick(section.value)"
      >
        {{ section.label }}
      </b-list-group-item>
    </b-list-group>
  </b-col>
</template>

<script>
export default {
  name: 'AdminSidebarL',

  props: {
    contentSection: String
  },
  data() {
    return {
      activeSection: '/org/data',
      sections: [
        { label: 'Данные', value: '/org/data' },
        { label: 'Классы', value: '/org/classes' },
        { label: 'Пользователи', value: '/org/users' },
        { label: 'Приглашения', value: '/org/invites' }
      ]
    };
  },

  methods: {
    handleClick(sectionValue) {
      this.activeSection = sectionValue;

      this.$root.$emit('renderContentSection', this.activeSection);
    }
  }
};
</script>

<style scoped>
.sidebar {
  max-width: 300px;

  min-height: inherit;
  border-right: #2c3e50 1px solid;
  resize: horizontal;
}
.list-group > div {
  cursor: pointer;
}
</style>