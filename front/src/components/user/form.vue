<script>
import editAbsent from "@/components/admin/context-forms/data/editAbsent.vue";
export default {
  name: "userForm",
  props: {
    classData: {
      type: Object,
      required: true,
    },
  },
  components: {
    editAbsent,
  },
  data() {
    return {
      students: [],
      updatedAbsent: {},
    };
  },
  mounted() {
    console.log(this.classData)
    },
};
</script>

<template>
  <editAbsent :content="classData" />
</template>

<style scoped></style>