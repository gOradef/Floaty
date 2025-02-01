<script>
import router from "@/router";

export default {
  name: 'choseClass',
  data() {
    return {
      loadingClasses: false,
      isClassExists: true,
      classes: [],
    }
  },
  async mounted() {
    const res = await this.$root.$makeApiRequest('/api/user/classes');
    if (res.classes !== null) //if is not null, so no available class
      this.classes = res.classes;
    else {
      this.isClassExists = false;
    }
    this.loadingClasses = false;
  },
  created() {
    this.loadingClasses = true;
    this.classes = []
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
        <b-list-group v-if="isClassExists">
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
        <div v-else>
          <p>Похоже, что у вас нет доступа ни к одному классу. </p>
          <p>Если это поведение непредвиденно, то обратитесь к администратору организации.</p>
        </div>
      </b-overlay>
    </b-card>
  </div>
</template>

<style scoped></style>