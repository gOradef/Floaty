

<template>
  <div>
    <b-modal
        ref="modal"
        :title="this.Interface.title.toString()"
        @hide="closeModal"
    >
      <div>
        <notificationsForm :notifications="notifications"/>
        <component
            v-if="showModal"
            :is="this.Interface.type"
            :action="this.Interface.action"
            :entity="this.contextData"
        />
      </div>
      <template v-slot:modal-footer>
        <b-button variant="secondary" @click="closeModal">Закрыть</b-button>
        <b-button variant="primary" type="submit" @click="submitForm">Подтвердить</b-button>
      </template>
    </b-modal>

    <div v-if="showContextOptions">
      <h3 style="border-bottom: #2c3e50 1px dotted">{{ contextData.name }}</h3>

      <!--    Button group -->
      <b-button-group vertical class="mt-2">
        <div v-for="(option, index) in contextOptions" :key="index">
          <b-button class="w-100" :variant="option._variant" @click="option.foo">
            {{ option.label }}
          </b-button>
        </div>
      </b-button-group>
    </div>
  </div>
</template>


<script>
import dataInterface from "@/components/admin/context-forms/dataInterface.vue";
import classesInterface from "@/components/admin/context-forms/classesInterface.vue";
import usersInterface from "@/components/admin/context-forms/usersInterface.vue";
import invitesInterface from "@/components/admin/context-forms/invitesInterface.vue";

import NotificationsForm from "@/components/admin/notifications.vue";


export default {
  name: "AdminContextMenu",
  components: { NotificationsForm },
  data() {
    return {
      Interface: {
        type: Object,
        action: String,
        title: String,
      },
      showModal: false,
      showContextOptions: false,

      contextOptions: [], // Buttons with actions
      contextData: "",

      notifications: [],

      template_contextOptions: {
        data: [ //Region Data
          {
            label: "Редактировать список отсутств.",
            foo: () =>
              this.openModal(dataInterface, "edit", "Редактировать данные"),
          },
          {
            label: "Сбросить запись - В разработке",
            foo: () => this.openModal(dataInterface, "delete"),
            _variant: "danger",
          },
        ],
        classes: [ //Region Class
          {
            label: "Создать новый класс",
            foo: () =>
              this.openModal(
                  classesInterface,
                  "create",
                  "Создать новый класс"),
          },
          {
            label: "Редактировать список учащихся",
            foo: () =>
              this.openModal(
                classesInterface,
                "edit",
                "Редактировать список учащихся"
              ),
          },
          {
            label: "Переименовать",
            foo: () =>
              this.openModal(classesInterface, "rename", "Переименовать класс"),
          },
          {
            label: "Удалить класс",
            foo: () =>
              this.openModal(
                  classesInterface,
                  "delete",
                  "Удалить класс"),
                  _variant: "danger",
          },
        ],
        users: [ //Region User
          {
            label: "Создать",
            foo: () =>
                this.openModal(usersInterface,
                    "create",
                    "Создать пользователя"),
          },
          {
            label: "Редактировать",
            foo: () =>
                this.openModal(usersInterface,
                    "edit",
                    "Редактировать пользователя"),
          },
          {
            label: "Установить пароль",
            foo: () =>
                this.openModal(usersInterface,
                    "reset",
                    "Установить пароль"),
          },
          {
            label: "Удалить",
            foo: () =>
              this.openModal(usersInterface,
                  "delete",
                  "Удалить пользователя"),
            _variant: "danger",
          },
        ],
        invites: [ //Region Invites
          {
            label: "Создать приглашение",
            foo: () =>
                this.openModal(invitesInterface,
                    "create",
                    "Создать приглашение"),
          },
          {
            label: "Удалить",
            foo: () =>
                this.openModal(invitesInterface,
                    "delete",
                    "Удалить приглашения"),
            _variant: "danger",
          },
        ],
      },
    };
  },
  beforeMount() {
    this.$root.$off("context:show");
    this.$root.$off("context:hide");
    this.$root.$off("modal:hide");
    this.$root.$off("notification");
  },
  mounted() {
    this.$root.$on("context:show", (section, row) => {
      this.showContextOptions = true;
      if (this.template_contextOptions[section]) {
        // Check if section exists and use it
        this.contextOptions = this.template_contextOptions[section];
      }
      this.contextData = row[0]; // Assuming row has data you want to store
    });
    this.$root.$on("context:hide", () => {
      this.showContextOptions = false;
      this.contextOptions = []; // Clear options when hiding
      this.notifications = [];
    });
    this.$root.$on("modal:hide", () => {
      this.notifications = [];
      this.closeModal();
    });
  },
  methods: {
    openModal(Interface, action, title) {
      this.Interface.type = Interface;
      this.Interface.action = action;
      this.Interface.title = title;
      this.$refs["modal"].show();
      this.showModal = true;
    },
    closeModal() {
      this.$refs["modal"].hide();
      this.showModal = false;

      this.Interface.action = "";
    },
    submitForm() {
      this.$root.$emit('form:confirm'); // Emit submit event on the child component
    },
  },
};
</script>

<style scoped lang="postcss">
.btn-group-vertical {
  align-items: center;
  min-width: 260px;
  width: 100%;
}
.btn-group-vertical > div {
  margin-bottom: 5px;
  min-width: 180px;
  width: 70%;
}
.btn-group-vertical > div > .btn {
  width: 100%;
  min-width: 180px;
}
</style>