<template>
  <b-container fluid class="d-flex align-items-center justify-content-center min-vh-100 bg-light">
    <b-card class="shadow-sm" style="width: 400px;">
      <b-overlay :show="isLoading">
      <!--   Login     -->
        <b-card-body v-if="isShowLogin">
          <h4 class="card-title text-center">Вход</h4>

          <b-form @submit.prevent="onSubmit">
            <b-form-group label="Логин" label-for="login">
              <b-form-input
                  id="login"
                  type="text"
                  required
                  v-model="username"
                  placeholder="Введите логин">
              </b-form-input>
            </b-form-group>

            <b-form-group label="Пароль" class="mb-2" label-for="password">
              <b-form-input
                  id="password"
                  type="password"
                  required
                  v-model="password"
                  placeholder="Введите пароль">
              </b-form-input>
            </b-form-group>
            <b-form-checkbox
                class="mb-3"
                v-model="rememberMe"
            >
              Запомнить меня?
            </b-form-checkbox>

            <!-- Alert for login status -->
            <b-alert
                v-model="showAlert"
                :variant="alertVariant"
                dismissible
                @dismissed="showAlert = false">
              {{ alertMessage }}
            </b-alert>

            <b-button type="submit" variant="primary" block>Войти</b-button>
          </b-form>

          <div class="text-center mt-2">
            <router-link to="/signup/invite" style="text-decoration: underline;">
              Есть приглашение?
            </router-link>
          </div>
        </b-card-body>

        <b-card-body class="mt-3">
          <h5 v-if="isShowRoles && !hasRefreshToken" class="mb-2 text-center"> Здравствуйте, <br>
            {{actualUserName}}
             👋
          </h5>
          <h5 v-if="hasRefreshToken" class=" mb-2 text-center">
            С возвращением, <br> {{actualUserName}} 👋
          </h5>
          <RoleSelect v-if="hasRefreshToken || isShowRoles"/>
          <div v-if="isUserDoesntHaveAnyRoles">
            <h4>Доступ запрещён.</h4>
            <p>Вы не владеете ни одной ролью в данной организации. Чтобы получить права для заполнения / редактирования данных, обратитесь к администратору организации</p>
          </div>
        </b-card-body>
      </b-overlay>
    </b-card>
  </b-container>
</template>
<script>
import axios from 'axios';
import roleSelect from "@/components/roleSelect.vue";

export default {
  name: 'LoginPage',
  components: {
    RoleSelect: roleSelect
  },
  data() {
    return {
      username: '',
      password: '',
      rememberMe: false,

      showAlert: false,
      alertMessage: '',
      alertVariant: 'success', // Default to success, can be changed to 'danger' for errors

      hasRefreshToken: false,
      isLoading: false,

      isShowLogin: true,
      isShowRoles: false,
      actualUserName: '',
      isUserDoesntHaveAnyRoles: false,
    };
  },
  async mounted() {
    await this.checkForRefreshToken();
  },
  methods: {
    getCookie(name) {
      const cookies = document.cookie.split(';');
      for (let i = 0; i < cookies.length; i++) {
        const cookie = cookies[i].trim();
        if (cookie.startsWith(name + '=')) {
          return cookie.substring(name.length + 1);
        }
      }
      return null;
    },
    async loginProcess() {

      await new Promise(r => setTimeout(r, 500));
      this.showAlert = true;
      this.isLoading = false;
      await new Promise(r => setTimeout(r, 400));

    },
    async successfulLogin(response) {
      console.log(response);
      this.alertMessage = 'Успешно!';
      this.alertVariant = 'success';

      await this.loginProcess();

      if (response.data.user.name) {
        this.actualUserName = response.data.user.name;
        //Saving name of user
        const expirationDate = new Date();
        expirationDate.setDate(expirationDate.getDate() + 7); // Set cookie expiration to 7 days from now
        document.cookie = `username=${this.actualUserName}; expires=${expirationDate.toUTCString()}; SameSite=Lax; path=/`;

        this.isShowRoles = true;
      }
      else
        this.isUserDoesntHaveAnyRoles = true;

    },
    async checkForRefreshToken() {
      const data = await this.$root.$makeApiRequest('/api/roles');

      if (data) {
        this.hasRefreshToken = true;
        this.actualUserName = this.getCookie('username');
      }
    },
    onSubmit() {
      this.isLoading = true;

      axios
          .post('/api/login', {
            login: this.username,
            password: this.password,
            rememberMe: this.rememberMe
          })
          .then(response => {
            this.successfulLogin(response);
          })
          .catch(error => {
            this.loginProcess();
            if (error.response.status === 502) {
              this.alertMessage = 'API-сервер не отвечает. Пожалуйста, попробуйте позже. ' +
                  'Приносим извинения за доставленные неудобства';
              this.alertVariant = 'warning'
            }
            if (error.response.status === 400) {
              this.alertMessage = 'Неправильный логин или пароль';
              this.alertVariant = 'danger'; // Show as error
            }
          });
    }

  },
};
</script>

<style scoped>
label {
  text-align: start;
}
</style>