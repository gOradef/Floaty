<template>
  <div class="sidebar">
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
  </div>
</template>

<script>
export default {
  name: 'AdminSections',

  props: {
    contentSection: String
  },
  data() {
    return {
      activeSection: '/org/data',
      sections: [
        { label: 'Данные', value: 'data' },
        { label: 'Классы', value: 'classes' },
        { label: 'Пользователи', value: 'users' },
        { label: 'Приглашения', value: 'invites' }
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
.list-group > div {
  cursor: pointer;
}
</style>