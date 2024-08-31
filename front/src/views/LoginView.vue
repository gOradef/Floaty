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

            <div v-if="hasRefreshCookie">
              <p>
                А мы вас помним :) <br>
                <b-button class="mt-1" @click="isShowRoles = true" >Востановить последнюю сессию?</b-button>
              </p>
            </div>
            <b-button type="submit" variant="primary" block :disabled="isShowRoles">Войти</b-button>
          </b-form>

          <div class="text-center mt-2">
            <router-link to="/signup/invite" style="text-decoration: underline;">
              Есть приглашение?
            </router-link>
          </div>
        </b-card-body>

        <b-card-body v-if="isShowRoles" class="mt-3">
          <h5 class="mb-2"> Здравствуйте,
            {{actualUserName}}
             👋
          </h5>
          <RoleSelect/>
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

      hasRefreshCookie: false,
      isLoading: false,

      isShowLogin: true,
      isShowRoles: false,
      actualUserName: '',
    };
  },
  async mounted() {
    await this.checkForRefreshToken();
  },
  methods: {
    async loginProcess() {

      // this.isLoading = true;
      // await new Promise(r => setTimeout(r, 1300));
      // this.showAlert = true;
      //
      // this.isLoading = false;
      // await new Promise(r => setTimeout(r, 400));

      await new Promise(r => setTimeout(r, 1500));
      this.showAlert = true;
      this.isLoading = false;
      await new Promise(r => setTimeout(r, 400));

    },
    async successfulLogin(response) {
      console.log(response);
      this.alertMessage = 'Успешно!';
      this.alertVariant = 'success';

      await this.loginProcess();

      this.actualUserName = response.data.user.name;
      this.isShowRoles = true;
    },
    async checkForRefreshToken() {
      // Check for the presence of the Floaty_refresh_token cookie
      const cookieName = 'Floaty_refresh_token=';
      const cookies = document.cookie.split(';');
      this.hasRefreshCookie = false; // Default to false

      for (let cookie of cookies) {
        cookie = cookie.trim();
        if (cookie.startsWith(cookieName)) {
          try {
            // Only call refreshAccessToken once and assign the result
            this.hasRefreshCookie = await this.$root.$refreshAccessToken();
            console.log("Successfully refreshed access token.", this.hasRefreshCookie);
            return; // Exit once the refresh token is found and processed
          } catch (err) {
            console.error('Failed to refresh access token:', err);
            this.hasRefreshCookie = false; // Set to false if refreshing the token fails
            return; // Exit early on error
          }
        }
      }
      // If we exit the loop without finding the cookie, hasRefreshCookie remains false
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