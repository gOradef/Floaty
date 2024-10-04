<template>
  <div class="hello">
    <b-jumbotron header="Floaty" lead="Сервис для заполнения отчётности удобоно, быстро, надежно">
      <h1>{{ msg }}</h1>
      <p>For more information visit website</p>
      <b-button variant="primary" href="/about">More Info</b-button>
    </b-jumbotron>

    <b-container>
      <section class="about">
        <h2>О нас</h2>
        <p>Мы - независимая команда разработчиков. Мы создали Floaty, чтобы улучшить учебный процесс, уменьшив количество требуемого времени для учителей и администраторов.</p>
        <img src="https://via.placeholder.com/300" alt="О нас">
      </section>

      <section class="strong-sides">
        <h2>Наши сильные стороны</h2>
        <b-row>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Опыт в разработке образовательных проектов</b-card-title>
                <b-card-text>Мы имеем опыт в разработке образовательных проектов, которые помогают улучшить учебный процесс.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Знание образовательной сферы</b-card-title>
                <b-card-text>Мы хорошо знаем образовательную сферу и понимаем, какие проблемы необходимо решить.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Команда профессионалов</b-card-title>
                <b-card-text>Мы - команда профессионалов, которая имеет опыт в разработке образовательных проектов.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
        </b-row>
      </section>

      <section class="possibilities">
        <h2>Возможности Floaty</h2>
        <b-row>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Быстрая отчетность</b-card-title>
                <b-card-text>Floaty позволяет вам быстро создавать отчеты, сохраняя время и усилия.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Удобный интерфейс</b-card-title>
                <b-card-text>Floaty имеет простой и интуитивно понятный интерфейс, который легко использовать.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Улучшение учебного процесса</b-card-title>
                <b-card-text>Floaty помогает улучшить учебный процесс, уменьшив количество требуемого времени для учителей и администраторов.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
        </b-row>
      </section>

      <section class="origin">
        <h2>Начальная образовательная организация</h2>
        <p>Мы начали наш проект в образовательной организации "Новая Школа", где мы работали над разработкой образовательных проектов.</p>
        <img src="https://via.placeholder.com/300" alt="Начальная образовательная организация">
      </section>

      <section class="contact">
        <h2>Контакты</h2>
        <p>Если у вас есть вопросы или предложения, пожалуйста, свяжитесь с нами.</p>
        <img src="https://via.placeholder.com/300" alt="Контакты">
      </section>
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'HelloWorld',
  props: {
    msg: String
  }
}
</script>

<style>
.hello {
  margin-top: 50px;
}
.about,.strong-sides,.possibilities,.origin,.contact {
  margin-top: 50px;
}
</style>