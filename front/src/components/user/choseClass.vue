<script>
import router from "@/router";

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
      this.selectedClassUUID = classt; // Update selected class

      router.push('/form/' + this.selectedClassUUID.id);
    },
    isActive(classt) {
      return this.selectedClassUUID === classt; // Check if the class is active
    }
  }
}
</script>

<template>
  <div
      style="min-height: 90vh"
    class="d-flex align-items-center justify-content-center"
  >
  <b-card title="Выберите класс">
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
    </b-card>
  </div>
</template>

<style scoped></style>