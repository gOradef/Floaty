<template>
  <div>
    <b-jumbotron
        fluid>

      <template #header>
        404
      </template>
      <template #lead>

        <p style="font-size: 2rem">
          Ой... Страница не существует
        </p>
        <span> Мы не смогли найти данную страницу для вас 😔</span> <br>
        <span>Вернуться на <a href="/">главную</a> страницу?</span>

      </template>
    </b-jumbotron>
  </div>
</template>

<script>

export default {
  name: "NotFound"
}
</script>

<style scoped>

</style>
