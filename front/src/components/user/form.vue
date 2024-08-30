<script>

export default {
  name: "userForm",
  props: {
    classData: {
      type: Object,
      required: true,
    },
  },
  components: {

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