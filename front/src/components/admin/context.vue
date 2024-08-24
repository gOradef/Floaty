<script>
import editAbsentAmount from "@/components/admin/context-forms/data/editAbsentAmount.vue";

export default {
  name: "AdminContextMenu",
  data() {
    return {
      currentForm: {},
      titleModal: '',
      showModal: false,
      showContextOptions: false,

      contextOptions: [ ],
      contextData: '',

      template_contextOptions: {
        data: [
          {
            label: 'Редакт. кол-во отсутств.',
            foo: () => this.openModal(editAbsentAmount)
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
    this.$root.$on('notification', (type, msg) => {
      switch(type) {
        case: "success"
          break;
        case: "alert"
          break;

      }
    });
  },
  methods: {
    openModal(type) {
      this.currentForm = type;
      this.showModal = true;
      this.titleModal = this.currentForm.data().modal.title;
    },
    resetModal() {
      this.showModal = false;
      this.currentForm = null;
    },
    formConfirm() {
      this.$root.$emit('form:confirm');
    }
  }
};
</script>

<template>
  <div>
    <b-modal v-model="showModal" :title="titleModal" @hide="resetModal">
      <template v-slot:modal-footer>
        <b-button variant="secondary" @click="showModal = false">Close</b-button>
        <b-button variant="primary" @click="formConfirm">Save</b-button>
      </template>
      <div>
        <component v-bind:content="contextData" :is="currentForm"></component>
      </div>
    </b-modal>


    <h3 style="border-bottom: #2c3e50 1px dotted"> {{contextData.name}}</h3>

<!--    Button group -->
  <b-button-group vertical v-if="showContextOptions">
        <div v-for="(option, index) in contextOptions"
             :key="index">
      <b-button :variant="option._variant" @click="option.foo">
        {{option.label }} <!-- Assuming each option has a label to display -->
      </b-button>
        </div>
  </b-button-group>

  </div>
</template>

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