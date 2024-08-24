<script>
export default {
  name: "editAbsentAmount",
  props: ["content"],
  setup() {
    console.log("Setup called");
    this.updatedAbsent = this.content.absent;
    this.students = this.content.list_students
    this.fstudents = this.content.list_fstudents
  },
  data() {
    return {
      updatedAbsent: {},
      students: [],
      fstudents: [],
      modal: {
        title: 'Редактирование кол-ва остутств.'
      }
    };
  },
  mounted() {
    this.$root.$on('form:confirm',() =>  {
    //   Inserting data
      console.log("Inserted!");
    })
  },
};
</script>

<template>
  <b-form title="Редактировать кол-во отсутств. учащихся">
    <h4> Класс: {{content.name}}</h4>
    <h6>Список учеников: </h6>
    <b-form-tags v-model="students">

    </b-form-tags>
    <b-list-group v-for="(cause, index) in content.absent" :key="index">
      <!--//todo list students -->
      <label for="tags-basis">{{index}}</label>
      <b-form-tags v-model="updatedAbsent.ORVI "></b-form-tags>
    </b-list-group>
  </b-form>
</template>

<style scoped></style>