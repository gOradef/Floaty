<template>
  <div>
    <!-- Modal for Tags -->
    <b-modal v-model="modalVisible" :title="titleModal" @hide="resetModal">
      <template v-slot:modal-footer>
        <b-button variant="secondary" @click="modalVisible = false">Close</b-button>
        <b-button variant="primary" @click="saveTags">Save</b-button>
      </template>
      <div>
        <b-form-group label="Tags">
          <b-form-input v-model="tagsInput" placeholder="Enter tags"></b-form-input>
        </b-form-group>
      </div>
    </b-modal>

    <h3 style="border-bottom: #2c3e50 1px dotted"> {{contextData.name}}</h3>
  <b-button-group vertical v-if="showContextOptions">
        <div v-for="(option, index) in contextOptions"
             :key="index">
      <b-button :variant="option._variant" @click="callAction(option.foo)">
        {{option.label }} <!-- Assuming each option has a label to display -->
      </b-button>
        </div>
  </b-button-group>
  </div>
</template>

<script>
export default {
  name: "AdminContextMenu",
  data() {
    return {
      modalContent: {
        data: {
          editAbsentAmount: false //set num,
          editAbsentFios: false, //tags
          setDataFilled: false //check
        },
        classes: {
          create: false, //form (name, amount, <owner>)
          editOwners: false, //tags + suggest users
          rename: false, //set String
          delete: false //confirm
        },
        users: {
          create: false, //form (name, login, password, <roles>, <classes>)
          editRoles: false, //tags
          editClasses: false, //tags + suggest users
          rename: false, //set String
          delete: false, //confirm
        },
        invites: {
          create: false, // form name, class
          delete: false //confirm
        }
      },
      currentModal: '',
      titleModal: '',
      showModal: false,
      showContextOptions: false,

      contextOptions: [ ],
      contextData: '',

      template_contextOptions: {
        data: [
          {
            label: 'Редакт. кол-во отсутств.',
            foo: 'setAbsentAmount'
          },
          {
            label: 'Редакт. фамилии отсутств.',
            foo: ''
          }

        ],
        classes: [
          {
            label: 'Создать новый класс',
            foo: ''
          },
          {
            label: 'Редактировать список учащихся',
            foo: ''
          },
          {
            label: 'Переименовать',
            foo: ''
          },
          {
            label: 'Удалить класс',
            foo: '',
            _variant: 'danger'
          }
        ],
        users: [
          {
            label: 'Создать',
            foo: ''
          },
          {
            label: 'Редактировать',
            foo: ''
          },
          {
            label: 'Установить пароль',
            foo: ''
          },
          {
            label: 'Удалить',
            foo: ''
          }
        ],
        invites: [
          {
            label: 'Создать приглашение',
            foo: ''
          },
          {
            label: 'Удалить',
            foo: ''
          }
        ]
      }
    };
  },
  mounted() {
    this.$root.$on('context:show', (section, row) => {
      this.showContextOptions = true;
      if (this.template_contextOptions[section]) {
        // Check if section exists and use it
        this.contextOptions = this.template_contextOptions[section];
      }
      this.contextData = row[0]; // Assuming row has data you want to store
    });
    this.$root.$on('context:hide', () => {
      this.showContextOptions = false;
      this.contextOptions = []; // Clear options when hiding
    });
  },
  methods: {
    setAbsentAmount() {
      this.showModal = true;
      // console.log("SETED");
    },
    setAbsentFios() {
      this.showModal = true;

    },
    callAction(action) {
      if (this[action]) {
        this[action]();  // Call the method referenced
      } else {
        console.warn(`Method ${action} is not defined.`);
      }
    },
    openModal(type) {
      this.currentModal = type;
      this.modalVisible = true;
    },
    resetModal() {
      this.modalVisible = false;
      this.tagsInput = '';
      this.integerValue = null;
      this.renameInput = '';
    },
  }
};
</script>

<style scoped lang="postcss">
.btn-group-vertical {
  align-items: center; min-width: 260px
}
.btn-group-vertical > div {
  margin-bottom: 5px;
  min-width: 180px;
}
.btn-group-vertical > div > .btn {
  min-width: 180px;
}
</style>