<template>
  <b-col>
      <b-table striped hover :items="items" :fields="fields" >
      </b-table>
  </b-col>
</template>

<script>
// import axios from "axios";

export default {
  name: "AdminContent",
  data() {
    return {
      items: [],
      fields: [
        {
          key: "name",
          label: "Класс",
          sortable: true
        },
        {
          key: "amount",
          label: "Кол-во"
        },
        {
          key: "owner.name",
          label: "Кл. рук."
        }

      ],
      raw_data: Object
    }
  },
  mounted() {
    this.$root.$on('renderContentSection', async (section) => {

      console.log('hi' + section)

      this.raw_data = {
        "300cf306-33c9-4bbc-996c-c5b2e03997ba": {
          "list_fstudents": [], // Free students
          "list_students": [ // All including free students
            "Ivanov1"
          ],
          "amount": 0,
          "owner": {
            "name": "Tester Floatyev Ivanich",
            "id": "ac7d9df6-9141-461b-bd12-f59370fb9826"
          },
          "name": "99_F"
        }
      };

      this.items = Object.keys(this.raw_data).map(key => ({
        id: key,
            ...this.raw_data[key]
      }));
      console.log(this.items);
    })
  }
}
</script>
<style scoped></style>