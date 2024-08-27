<script>
export default {
  name: 'choseClass',
  data() {
    return {
      loadingClasses: false,
      classes: [],
    }
  },
  async mounted() {
    const res = await this.$root.$makeApiRequest('/api/user/classes');
    this.classes = res.classes;
  },
  created() {
    this.loadingClasses = true;
    this.classes = []
    this.loadingClasses = false;
  },
  methods: {
    chooseClass(classt) {
      this.selectedClass = classt; // Update selected class
      this.$root.$emit('class:select', this.selectedClass);
    },
    isActive(classt) {
      return this.selectedClass === classt; // Check if the class is active
    }
  }
}
</script>

<template>
      <b-overlay :show="loadingClasses">
        <b-list-group >
          <b-list-group-item
              v-for="(classt, index) in classes"
              :key="index"
          @click="chooseClass(classt)"
          :class="{ active: isActive(classt) }"
          :id="index"
          role="button"
          tabindex="0"
          @keypress.enter="chooseClass(classt)"
          >
          {{ classt.name }}
          </b-list-group-item>
        </b-list-group>
      </b-overlay>
</template>

<style scoped></style>