<template>
<div>
  <!-- Navigation Bar -->
  <nav class="navbar navbar-default">
  <div class="container-fluid">
    <div class="navbar-header">
      <a class="navbar-brand" href="#">
        <i class="fa fa-codepen fa-lg"></i>
      </a>
    </div>
  </div>
  </nav>

      <h2 class="card-title text-center mb-0">Регистрация</h2>
      <h4 class="text-center pt-0">с помощью приглашения</h4>
  <!-- Stepper Component -->
  <div class="flex-container container">
  <!-- Progress Bar -->
  <div class="progress" :style="pBarSize">
    <div class="progress-bar"
         role="progressbar"
         aria-valuenow="60"
         aria-valuemin="0"
         aria-valuemax="100"
         :style="progress">
    </div>
  </div>

  <!-- Stepper Steps -->
  <div class="step"
       v-for="(step, i) in stepper.steps"
       :key="i"
       :class="{
         done: (step.number < stepper.currentStep && step.state()),
         wrong: (step.number < stepper.currentStep && !step.state()),
         current: step.number === stepper.currentStep }">
    <div class="step-label">{{step.label}}</div>
    <div class="step-number"
         :id="'step-'+step.number"
         v-on:click="moveStep(step.number)">
      <i v-if="step.number < stepper.currentStep" class="fa fa-check"></i>
      <span v-else>{{step.number}}</span>
    </div>
  </div>
  </div>

  <!-- Content Section -->
  <div class="container">

  <!-- Registration Section -->
    <b-card-body v-if="stepper.currentStep === 1">
      <h5 class="text-center">Введите ID организации, которая предоставила вам приглашение</h5>
      <b-form-group label="ID организации">
        <div class="d-flex">
          <b-form-input v-model="v_orgID" :state="isOrgValid" @input="checkOrg"/>
          <b-button @click.stop="checkOrg" variant="primary">
            <b-icon icon="arrow-return-right"/>
          </b-button>
        </div>
      </b-form-group>
      <b-card>
        <div v-if="isOrgSelected && isOrgValid">
          <b-card-title>
            <i>{{ orgData.title }}</i>
          </b-card-title>
          <b-card-body>
            <p>
              Город организации: <i>{{ orgData.city }}</i>
            </p>
            <p>
              Контактная информация: <i>{{ orgData.email }}</i>
            </p>
          </b-card-body>
        </div>
        <div v-else-if="isOrgSelected &&!isOrgValid">
          <h3>Организация с данным ID не найдена</h3>
        </div>
        <div v-else>
          <p>Введите ID организации</p>
        </div>
      </b-card>
      <b-button
          :disabled="!(isOrgSelected && isOrgValid)"
          v-on:click="moveStep(stepper.currentStep+1)"
          class="alert-success mt-2" role="button">
        Продолжить
      </b-button>
    </b-card-body>

  <!-- Invitation Section -->
  <b-card-body v-else-if="stepper.currentStep === 2">
    <h4 class="card-title text-center mb-0">Введите данные приглашения</h4>
    <b-form @submit.prevent="onSubmit">
        <b-form-group label="ID приглашения" label-for="login">
          <b-form-input
              id="login"
              type="text"
              required
              :state="isInviteValid"
              v-model="invite.id"
              @input="checkInvite"
              placeholder="Введите id"
          >
          </b-form-input>
        </b-form-group>

        <b-form-group label="Секрет приглашения" class="mb-2" label-for="password">
          <b-form-input
              id="password"
              type="text"
              required
              :state="isInviteValid"
              v-model="invite.secret"
              @input="checkInvite"
              placeholder="Введите секрет"
          >
          </b-form-input>
        </b-form-group>
<!--        <b-button-->
<!--        :disabled="!isInviteWrited"-->
<!--        variant="info"-->
<!--        v-on:click="checkInvite"-->
<!--        > Проверить приглашение</b-button>-->

      <!-- Alert for Invitation Status -->
      <b-card v-if="isInviteValid">
        <b-card-title>
          <i>{{inviteData.userName}} </i>
        </b-card-title>
        <b-card-body>
          <p>Доступные роли: <i> {{inviteData.roles.join(', ')}} </i></p>
          <p>Доступные классы: <i> {{(inviteData.classes.map(classt => {return classt.name})).join(', ')}} </i></p>
        </b-card-body>
      </b-card>
    </b-form>
    <b-button
        :disabled="!(isInviteWrited && isInviteValid)"
        v-on:click="moveStep(stepper.currentStep+1)"
        class="btn alert-success mt-2"
        role="button">Продолжить</b-button>
  </b-card-body>

  <!-- Authorization Section -->
  <b-card-body v-if="stepper.currentStep === 3">
    <h4 class="card-title text-center mb-0">Введите логин и пароль</h4>
    <h6 class="text-center">Учтите что, в отличии от пароля, логин изменить будет невозможно.</h6>
    <h5 class="mb-2">
      {{ inviteData.actualUserName }}
    </h5>
      <b-form @submit.prevent="onSubmit">
        <b-form-group label="Логин" label-for="login">
          <b-form-input
              id="login"
              type="text"
              required
              :state="isCredsValid"
              v-model="userCreds.login"
              @change="checkCreds"
              placeholder="Введите логин"
          >
          </b-form-input>
        </b-form-group>

        <b-form-group label="Пароль" class="mb-2" label-for="password">
          <b-form-input
              id="password"
              type="text"
              required
              :state="isCredsValid"
              v-model="userCreds.password"
              @change="checkCreds"
              placeholder="Введите пароль"
          >
          </b-form-input>
        </b-form-group>
        <b-form-group label="Подтвердите пароль" class="mb-2" label-for="password">
          <b-form-input
              id="password"
              type="text"
              required
              :state="isCredsValid"
              v-model="userCreds.password2"
              @change="checkCreds"
              placeholder="Введите пароль"
          >
          </b-form-input>
        </b-form-group>

      </b-form>
      <b-button
          :disabled="!(isCredsValid)"
          v-on:click="moveStep(stepper.currentStep+1)"
          class="btn alert-success mt-2"
          role="button">Продолжить</b-button>
  </b-card-body>

  <!-- Login Section -->
  <b-card-body v-if="stepper.currentStep === 4">
    <h4 class="card-title text-center mb-0">Подтвердите введёные данные</h4>
    <div id="statusFill">
      <b-alert variant="success" dismissible :show="isOrgValid">
        Организация выбрана корректно.
      </b-alert>
      <b-alert variant="danger" dismissible :show="!isOrgValid">
        Организация не выбрана корректно. Пожалуйста, вернитесь к 1-ому шагу.
      </b-alert>

      <b-alert variant="success" dismissible :show="isInviteValid">
        Приглашение идентифицированно.
      </b-alert>
      <b-alert variant="danger" dismissible :show="!isInviteValid">
        Приглашение не подтверждено. Пожалуйста, вернитесь к 2-ому шагу.
      </b-alert>

      <b-alert variant="success" dismissible :show="isCredsValid">
        Реквезиты для вохда заполнены корректно.
      </b-alert>
      <b-alert variant="danger" dismissible :show="!isCredsValid">
        Реквезиты для входа заполнены некорректно. Пожалуйста, вернитесь к 3-ому шагу.
      </b-alert>

      <b-alert variant="danger" dismissible :show="isLoginInUse && isLoginCheckPass">
        Логин уже используется другим пользователем. Пожалуйста, введите новый.
      </b-alert>

    </div>
    <b-card>
        <b-card-title>
          Организация <i>{{this.orgData.title}} </i>
        </b-card-title>
      <b-card-body>
        <p>Город: {{this.orgData.city}}</p>
        <p>Контактная информация: {{this.orgData.email}} </p>
      </b-card-body>

    </b-card>
    <b-card>
      <b-card-title>
        Приглашение: <i>{{this.invite.id}} | {{this.invite.secret}}</i>
      </b-card-title>

    </b-card>
    <b-card title="Реквезиты для входа">
        <b-card-body>
          <p>Логин: <i>{{this.userCreds.login}}</i></p>
          <p>Пароль: <i>{{this.userCreds.password}}</i></p>
        </b-card-body>
    </b-card>
    <b-button variant="primary" @click.stop="createUserWithInvite" :disabled="(isOrgValid ^ isInviteValid ^ isCredsValid) !== 1">Продолжить</b-button>
    <h6 v-if="(isOrgValid ^ isInviteValid ^  isCredsValid) !== 1">Один из шагов не заполнен или заполнен, но некорректно</h6>
    <b-alert variant="success" :show="isSuccessCreate">
      Пользователь успешно создан. Теперь перейдите по <router-link to="/login">этой</router-link> ссылке, чтобы войти в систему
    </b-alert>
    <b-alert variant="warning" :show="isLoginInUse">
      Пользователь с данным логином уже существует. Пожалуйста, введите другой логин
    </b-alert>
  </b-card-body>
  </div>

  <!-- Navigation Buttons -->
  <div class="col-sm-12" v-if="stepper.currentStep > 1 && stepper.currentStep <= stepper.steps.length">
  <button v-if="stepper.currentStep > 1"
          v-on:click="moveStep(stepper.currentStep-1)"
          class="btn btn-default"
          role="button">
    <b-icon class="fa" icon="chevron-left" aria-hidden="true"/> </button>
  <button v-if="stepper.currentStep < stepper.steps.length"
          v-on:click="moveStep(stepper.currentStep+1)"
          class="btn btn-default pull-right"
  role="button">Next <i class="fa fa-chevron-right" aria-hidden="true"></i></button>
  </div>
  <div v-else>
  <button v-on:click="moveStep(1)"
          class="btn btn-default btn-block"
          role="button">Reset <i class="fa fa-refresh" aria-hidden="true"></i></button>
  </div>
</div>

</template>

<script>
export default {
  name:'signupInvite',
  props: {
    orgID: {
      type: String,
      required: false
    }
  },
  async mounted() {
    //   Check if uuid exists
    const isUUIDExists = (this.orgID!== '');

    //   Check if uuid of org is valid
    if (isUUIDExists) {
      await this.checkOrg();
    } else {
      this.isOrgValid = false;
      this.isOrgSelected = false;
    }
  },
  data() {
    return {
      showAlert: false,
      alertMessage: '',
      alertVariant:'success', // Default to success, can be changed to 'danger'

      isLoading: false,

      stepper: {
        steps: [
          {
            number: 1,
            label: 'Выбор организации',
            state: () => {return this.isOrgValid}
          },
          {
            number: 2,
            label: 'Ввод приглашения',
            state: () => {return this.isInviteWrited && this.isInviteValid}
          },
          {
            number: 3,
            label: 'Реквезиты для входа',
            state: () => {return this.isCredsValid}
          },
          {
            number: 4,
            label: 'Подтверждение'
          }
        ],
        currentStep: 1,
      },

      isOrgSelected: false,
      isOrgValid: null,
      isInviteWrited: false,
      isInviteValid: null,
      isCredsWrited: false,
      isCredsValid: null,
      isLoginCheckPass: false,
      isLoginInUse: false,

      isSuccessCreate: false,

      v_orgID: this.orgID,
        orgData: {
          name: '',
          city: '',
          email: '',
        },

        invite: {
          id: '',
          secret: ''
        },

        inviteData: {
          userName: '',
          roles: [],
          classes: []
        },

        userCreds: {
          login: '',
          password: '',
          password2: ''
        },
        pBarSize: '',
        progress: '',
      }
    },
        computed: {
      isSuccessOrgStep() {
        return this.isOrgSelected && this.isOrgValid;
      }
    },
    methods: {
      async createUserWithInvite() {
        if (this.isOrgValid
            ^ this.isInviteValid
            ^ this.isCredsValid)
        {
          if (confirm('Пожалуйста, проверьте правильность заполненных данных, иначе повторить процедуру будет более невозможно')) {
            const status = await this.$root.$makeApiRequest(`/api/signup/invite/${this.v_orgID}`, 'POST',
                {
                  invite: {
                    code: this.invite.id,
                    secret: this.invite.secret
                  },
                  user: {
                    login: this.userCreds.login,
                    password: this.userCreds.password
                  },
                });
            if (status === 204) {
              this.isSuccessCreate = true;
            }
            else if (status === 409) {
              this.isSuccessCreate = false;
              this.isLoginInUse = true;
            }
          }
        } else {
          alert('Один из шагов не заполнен или заполнен, но некорректно')
        }

      },
      moveStep(stepNumber) {
        this.stepper.currentStep = stepNumber;
      },
      async checkOrg() {
        if (this.v_orgID!== ''
          // && this.v_orgID.length === 36
        ) {
          this.isOrgSelected = true;
          this.isOrgValid = await this.isValidUUID(this.v_orgID);
        } else {
          this.isOrgSelected = false;
          this.isOrgValid = false;
        }
      },
      async checkInvite() {
        if (this.invite.id !== '' && this.invite.secret !== '') {
          const data = await this.$root.$makeApiRequest(`/api/invite/${this.v_orgID}/${this.invite.id}/${this.invite.secret}`);
          console.log(data);
          if (data.status === 200) {
            this.inviteData.userName = data.invite.name;
            this.inviteData.roles = data.invite.roles;
            this.inviteData.classes = data.invite.classes;
            this.isInviteValid = true;
          }
          else
            this.isInviteValid = false;

          this.isInviteWrited = true;
        } else {
          this.isInviteWrited = false;
        }
      },
      checkCreds() {
        if (this.userCreds.login !== ''
        && this.userCreds.password !== ''
        && this.userCreds.password2 !== '')
        this.isCredsValid = this.userCreds.login !== ''
            && this.userCreds.password !== ''
            && this.userCreds.password2 !== '' && (this.userCreds.password === this.userCreds.password2);
      },
      async isValidUUID(uuid) {
        const isUUIDExists = (this.v_orgID !== '');

        //   Check if uuid of org is valid
        if (isUUIDExists) {
          try {
            const data = await this.$root.$makeApiRequest(`/api/org/${uuid}/info`);
            // console.log(data);
            if (data.status === 200) {
              this.orgData.title = data.org.title || '-';
              this.orgData.city = data.org.city || '-';
              this.orgData.email = data.org.email || '-';
            } else
              return false;
            return true;
          } catch (error) {
            console.error(error);
            return false;
          }
        } else {
          this.isOrgSelected = true;
          this.isOrgValid = false;
          return false;
        }
      }
    }
  }
</script>

<style scoped>
.flex-container {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 1em;
  transition: all 0.3s ease-in-out;
}

.progress {
  position: absolute;
  top: 2em;
  height: 5px;
  margin: 0;
  box-shadow: none;
  background-color: #cdcdcd;
  transition: width 0.3s ease-in-out;
}

.progress-bar {
  background-color: #46c0bd;
  transition: width 0.3s ease-in-out;
}

.step {
  text-align: center;
  z-index: 2;
  transition: all 0.3s ease-in-out;
}

.step-number {
  background-color: #cdcdcd;
  padding: 0.5em;
  color: white;
  border-radius: 2em;
  cursor: pointer;
  transition: background-color 0.3s ease-in-out;
}

.step-label {
  padding-top: 5px;
  transition: all 0.3s ease-in-out;
}

.done {
  .step-number {
    background-color: #94e594;
  }
}
.wrong {
  .step-number {
    background-color: #e74c5a;
  }
}

.current {
  .step-number {
    background-color: #b384c7;
  }
}
</style>