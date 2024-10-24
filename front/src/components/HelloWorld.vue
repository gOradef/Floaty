<template>
  <div class="hello">
    

    <b-container>
      <section class="about">
        <h2 class="d-flex justify-content-center">О нас</h2>
        <p>Мы - независимая команда разработчиков. Мы создали Floaty, чтобы улучшить учебный процесс, уменьшив количество требуемого времени для учителей и администраторов.</p>
      
      

      </section>

      <section class="strong-sides">
        <h2 class="d-flex justify-content-center">Наши сильные стороны</h2>
        <b-row>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Опыт в разработке образовательных проектов</b-card-title>
                <b-card-text>Мы уже имеем опыт в разработке образовательных проектов, а теперь улучшаем их для большего комфорта работы.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Работа с пользователями и обратная связь</b-card-title>
                <b-card-text>Мы понимаем, какие проблемы необходимо решить, ведь сами их наблюдали, опрашивали участников процесса, а также помогали с ними разобраться.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Наша команда</b-card-title>
                <b-card-text>Мы - команда исследователей-энтузистов, которая стреминтся помочь решить существующие проблемы.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
        </b-row>
      </section>

      <section class="possibilities">
        <h2 class="d-flex justify-content-center">Возможности Floaty</h2>
        <b-row>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Легкость в освоении и работе</b-card-title>
                <b-card-text>Floaty позволяет вам быстро создавать отчеты, сохраняя время и усилия, его легко освоить, а также изучать, чтобы каждый смог работать с нами.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Удобный интерфейс</b-card-title>
                <b-card-text>В процессе длительной работы и изучения мнения ползователей, была проведен глубокий анализ требований к дизайну, чтобы работать было еще проще.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
          <b-col md="4">
            <b-card>
              <b-card-body>
                <b-card-title>Улучшение учебного процесса</b-card-title>
                <b-card-text>Floaty помогает улучшить учебный процесс, уменьшив количество требуемого времени для учителей и администраторов, значительно уменьшая потраченное на заполнение отчтов время.</b-card-text>
              </b-card-body>
            </b-card>
          </b-col>
        </b-row>
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
