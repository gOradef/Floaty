<template>
  <div>
    <div
      id="versionContainer"
      v-for="(versionData, versionKey) in versions"
      :key="versionKey"
    >
      <b-card style="width: 90%; font-size: 0.93rem" class="border-0">
        <h4 class="mb-0 pb-0">
          <b> Изменения для {{ versionKey }} 🎉 </b>
        </h4>
        <i class="pl-2">{{ versionData.date }}</i>
        <b-card-body>
          <p class="versionDescription">{{ versionData.description }}</p>

          <div class="collapses">

            <!-- Features collapse -->
            <div class="border-bottom pb-2 mb-2" v-if="versionData.features">
              <div>
                <b-icon icon="plus-lg" class="mr-1"></b-icon>
                <a
                  class="b-skeleton-button"
                  style="cursor: pointer"
                  v-b-toggle="`features-${versionKey}`"
                  >Новые функции</a
                >
              </div>
              <b-collapse :id="`features-${versionKey}`">
                <ul style="">
                  <li v-for="feat in versionData.features" :key="feat">
                    {{ feat }}
                  </li>
                </ul>
              </b-collapse>
            </div>

            <!-- Improvements collapse -->
            <div
              class="border-bottom pb-2 mb-2"
              v-if="versionData.improvements"
            >
              <div>
                <b-icon icon="plus-lg" class="mr-1"></b-icon>
                <a
                  class="b-skeleton-button"
                  style="cursor: pointer"
                  v-b-toggle="`improvements-${versionKey}`"
                  >Улучшения</a
                >
              </div>
              <b-collapse :id="`improvements-${versionKey}`">
                <ul style="">
                  <li
                    v-for="improvement in versionData.improvements"
                    :key="improvement"
                  >
                    {{ improvement }}
                  </li>
                </ul>
              </b-collapse>
            </div>

            <!-- Fixes collapse -->
            <div class="border-bottom pb-2 mb-2" v-if="versionData.fixes">
              <div>
                <b-icon icon="plus-lg" class="mr-1"></b-icon>
                <a
                  class="b-skeleton-button"
                  style="cursor: pointer"
                  v-b-toggle="`fixes-${versionKey}`"
                  >Исправления</a
                >
              </div>
              <b-collapse :id="`fixes-${versionKey}`">
                <ul style="">
                  <li v-for="fix in versionData.fixes" :key="fix">{{ fix }}</li>
                </ul>
              </b-collapse>
            </div>


            <!-- Refactoring collapse -->
            <div class="border-bottom pb-2 mb-2" v-if="versionData.refactoring">
              <div>
                <b-icon icon="plus-lg" class="mr-1"></b-icon>
                <a
                  class="b-skeleton-button"
                  style="cursor: pointer"
                  v-b-toggle="`refactoring-${versionKey}`"
                  >Рефакторинг</a
                >
              </div>
              <b-collapse :id="`refactoring-${versionKey}`">
                <ul style="">
                  <li
                    v-for="refactor in versionData.refactoring"
                    :key="refactor"
                  >
                    {{ refactor }}
                  </li>
                </ul>
              </b-collapse>
            </div>

            <!-- Other collapse -->
            <div class="border-bottom pb-2 mb-2" v-if="versionData.other">
              <div>
                <b-icon icon="plus-lg" class="mr-1"></b-icon>
                <a
                  class="b-skeleton-button"
                  style="cursor: pointer"
                  v-b-toggle="`other-${versionKey}`"
                  >Другое</a
                >
              </div>
              <b-collapse :id="`other-${versionKey}`">
                <ul style="">
                  <li v-for="other in versionData.other" :key="other">
                    {{ other }}
                  </li>
                </ul>
              </b-collapse>
            </div>
          </div>
        </b-card-body>
      </b-card>
    </div>
  </div>
</template>

<script>
export default {
  name: "ReleaseNotes",
  data() {
    return {
      versions: {
        "1.3.0-b": {
          date: "3 января, 2024",
          description: "Добавлен логгер.",
          features: ["Добавлен логгер."],
        },
        "1.2.1": {
          date: "29 декабря, 2024",
          description:
            "Добавлена 404 страница и оптимизация соединений с базой данных.",
          improvements: [
            "Добавлена 404 страница.",
            "Оптимизация соединений с базой данных.",
          ],
        },
        "1.2.0": {
          date: "8 декабря, 2024",
          description: "Возвращена функция переименования пользователя.",
          features: ["Возвращена функция переименования пользователя."],
        },
        "1.1.8": {
          date: "7 декабря, 2024",
          description: "Оптимизация SQL-запросов.",
          fixes: ["Оптимизация SQL-запросов."],
        },
        "1.1.7": {
          date: "24 ноября, 2024",
          description:
            "Изменение перечисления ФИО бесплатников на их общее количество в функции экспорта.",
          refactoring: [
            "Изменение перечисления ФИО бесплатников на их общее количество в функции экспорта.",
          ],
        },
        "1.1.6": {
          date: "15 ноября, 2024",
          description: "Исправление SQL-запроса для генерации данных.",
          fixes: ["Исправление SQL-запроса для генерации данных."],
        },
        "1.1.5": {
          date: "14 ноября, 2024",
          description: "Оптимизация базы данных.",
          fixes: ["Оптимизация базы данных."],
        },
        "1.1.4": {
          date: "13 ноября, 2024",
          description:
            "Оптимизация API и исправление отображения бесплатников при экспорте.",
          fixes: [
            "Оптимизация API.",
            "Исправление отображения бесплатников при экспорте.",
          ],
        },
        "1.1.3": {
          date: "12 ноября, 2024",
          description:
            "Исправление фильтра по которому отображались бесплатники.",
          fixes: ["Исправление фильтра по которому отображались бесплатники."],
        },
        "1.1.2": {
          date: "11 ноября, 2024",
          description: "Изменение URL API для классного руководителя.",
          fixes: ["Изменение URL API для классного руководителя."],
        },
        "1.1.1": {
          date: "7 ноября, 2024",
          description: "Оптимизация SQL-запросов.",
          fixes: ["Оптимизация SQL-запросов."],
        },
        "1.1.0": {
          date: "5 ноября, 2024",
          description:
            "Добавлена функция получения данных за текущий день для классного руководителя.",
          features: [
            "Классный руководитель может получить данные за сегодняшний день.",
          ],
        },
        "1.0.1": {
          date: "25 октября, 2024",
          description:
            'Добавлена страница "Класс не найден" и улучшена интерфейс выбора роли.',
          features: [
            "Добавлена страница 'Класс не найден' при обращении по неверному ID класса или при недостатке прав для его редактирования.",
          ],
          improvements: ["Улучшение интерфейса выбора роли."],
        },
        "1.0.0": {
          date: "20 октября, 2024",
          description: "Добавлены новые функции и улучшения интерфейса.",
          fixes: [
            "Изменение статус кода для запроса об обновлении списка учащихся в классе.",
          ],
          features: [
            "Добавлен интерфейс редактирования учащихся для классного руководителя.",
            "Добавлена возможность удаления учащихся из класса для администратора и классного руководителя.",
            "Добавлено предупреждение классного руководителя при изменении локального списка учащихся без синхронизации с сервером.",
            "Добавлена функция сохранения имени пользователя в браузере.",
            "Добавлена функция 'Запомнить меня', позволяющая избежать ежедневного входа в систему.",
          ],
          improvements: [
            "Изменение URL маршрута /home.",
            "Небольшие изменения в навбаре.",
          ],
        },
        "0.9.2": {
          date: "19 октября, 2024",
          description:
            "Добавлена возможность удаления учащихся из класса и улучшена проверка прав доступа.",
          features: ["Добавлена возможность удаления учащихся из класса."],
          improvements: [
            "Переработана проверка наличия прав доступа для пользователя.",
          ],
        },
        "0.9.1": {
          date: "5 октября, 2024",
          description:
            "Исправлена ошибка возврата null в API при пустой таблице.",
          fixes: ["Исправление ошибки возврата null в API при пустой таблице."],
        },
        "0.9.0": {
          date: "4 октября, 2024",
          description:
            "Добавлена функция архивирования использованных приглашений и улучшена боковая панель.",
          features: [
            "Добавлена функция архивирования использованных приглашений.",
          ],
          improvements: ["Изменение боковой панели."],
        },
      },
    };
  },
  methods: {
    // Add any methods here
  },
};
</script>

<style>
.versionDescription {
  font-size: 0.88rem;
  font-family: Bricolage Grotesque, sans-serif;
  font-optical-sizing: auto;
  font-style: normal;
  font-weight: 500;
  font-variation-settings: "wdth" 100;
}

.collapses > div > .collapse {
  color: gray;
  font-size: 0.85rem;
}
</style>
