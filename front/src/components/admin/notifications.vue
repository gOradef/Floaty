<template>
  <div>
    <b-alert
        v-for="(notification, index) in notifications"
        :key="index"
        :variant="notification.variant"
        show
        dismissible
        @dismissed="removeNotification(index)"
    >
      {{ notification.msg }}
    </b-alert>
  </div>
</template>

<script>
export default {
  name: 'notificationsForm',
  data() {
    return {
      notifications: []
    }
  },
  beforeMount() {
    this.$root.$off('notification');
  },
  mounted() {
    this.$root.$on("notification", (variant, msg) => {
      switch (variant) {
        case "success":
          this.notifications.push({variant: 'success', msg: 'Успешно!'})
          break;
        case "error":
          this.notifications.push({variant: 'danger', msg: 'Ошибка!'})
          break;
        case "warning": // Wrong input
          this.notifications.push({variant: 'warning', msg: msg});
          break;
        case "status": // Get response
          if (msg.status === 200 || msg.status === 204)
            this.$root.$emit('notification', 'success', '');
          else {
            this.$root.$emit('notification', 'error', msg);
          }
          break;
      }
    });
  },
  methods: {
    removeNotification(index) {
      this.$emit('notification-remove', index);
    }
  }
}
</script>

<style scoped>

</style>