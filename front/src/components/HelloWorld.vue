<template>
  <div class="hello">

    <b-container>
      <b-jumbotron bg-variant="primary" text-variant="light" class="text-center p-5">
        <template #header>
          <h1>Floaty</h1>
        </template>
        <template #lead>
          <p>Инструмент заполнения отчётности для образовательных организаций.</p>
        </template>
        <p><i>Отчётность в облаках, управление на земле</i></p>
        <b-button variant="light" href="/login">Войти</b-button>
      </b-jumbotron>

      <section class="product">
        <h2 class="text-center mb-4">Что такое Floaty?</h2>
        <b-row>
          <b-col md="6">
            <b-card title="Отчётность в облаках" class="mb-4">
              <b-card-text>Floaty - это современный инструмент для заполнения отчётности об отсутствующих учащихся. Он обеспечивает удобный и эффективный способ взаимодействия с данными для администраторов и классных руководителей.</b-card-text>
            </b-card>
          </b-col>
          <b-col md="6">
            <b-card title="Удобство для всех" class="mb-4">
              <b-card-text>Мы создали Floaty, учитывая потребности как администраторов, так и классных руководителей. Теперь заполнение отчётности станет проще и быстрее для всех участников образовательного процесса.</b-card-text>
            </b-card>
          </b-col>
        </b-row>
      </section>

      <section class="possibilities">
        <h2 class="text-center mb-4">Возможности Floaty</h2>
        <b-row>
          <b-col md="4">
            <b-card class="mb-4">
              <b-card-title>Легкость в использовании</b-card-title>
              <b-card-text>Floaty имеет интуитивно понятный интерфейс, который позволяет быстро создавать и заполнять отчёты. Мы упростили процесс, чтобы сэкономить ваше время и усилия.</b-card-text>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card class="mb-4">
              <b-card-title>Удобный интерфейс</b-card-title>
              <b-card-text>Наш дизайн разработан с учётом отзывов пользователей. Мы стремимся сделать работу с Floaty максимально комфортной и эффективной.</b-card-text>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card class="mb-4">
              <b-card-title>Улучшение учебного процесса</b-card-title>
              <b-card-text>Floaty помогает оптимизировать учебный процесс, сокращая время, затрачиваемое на заполнение отчётов. Учителя и администраторы могут сосредоточиться на обучении, а не на рутинной работе.</b-card-text>
            </b-card>
          </b-col>
        </b-row>
      </section>

      <section class="strong-sides">
        <h2 class="text-center mb-4">Наши преимущества</h2>
        <b-row>
          <b-col md="4">
            <b-card class="mb-4">
              <b-card-title>Опыт в образовании</b-card-title>
              <b-card-text>Наша команда имеет опыт в разработке образовательных проектов. Мы на собственном примере знаем, с какими проблемами сталкиваются учебные заведения, и предлагаем эффективные решения.</b-card-text>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card class="mb-4">
              <b-card-title>Внимание к пользователям</b-card-title>
              <b-card-text>Мы ценим обратную связь и постоянно работаем над улучшением Floaty. Мы понимаем потребности пользователей и стремимся сделать наш инструмент максимально полезным и удобным.</b-card-text>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card class="mb-4">
              <b-card-title>Наша команда</b-card-title>
              <b-card-text>Мы - команда учеников, которые столкнулись с проблемами в образовательном процессе и решили предложить своё решение. Мы стремимся улучшить систему отчётности и сделать учебный процесс более эффективным. Наша страсть к технологиям и желание помочь делают нас движущей силой этого проекта.</b-card-text>
            </b-card>
          </b-col>
        </b-row>
      </section>

      <section class="about">
        <h2 class="text-center mb-4">О нас</h2>
        <p class="text-center">Мы - команда независимых разработчиков, которая стремится к совершенствованию образовательной сферы. Floaty - это наше решение, призванное упростить рутинные задачи и дать возможность сосредоточиться на обучении.</p>
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
  margin-top: 32px;
}
.about,.strong-sides,.possibilities,.origin,.contact {
  margin-top: 50px;
}
</style>
