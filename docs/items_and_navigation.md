# Objetos, listagem e integração do fluxo (`P10`–`P12`)

Documentação dos pacotes de Ruan Pedro de Araujo Anjos: adaptador HTTP de
objetos, estado e tela da listagem, montagem das dependências e navegação final.
Os textos da interface estão em português; o código, os identificadores e os
comentários técnicos, em inglês.

| Pacote | Entrega | Onde está |
| --- | --- | --- |
| `P10` | Adaptador HTTP de consulta e gravação de objetos | [`lib/features/lost_found/data/http_item_repository.dart`](../lib/features/lost_found/data/http_item_repository.dart) |
| `P11` | Estado, tela, cartões e atualização manual da listagem | [`item_list_notifier.dart`](../lib/features/lost_found/presentation/item_list_notifier.dart), [`item_list_screen.dart`](../lib/features/lost_found/presentation/item_list_screen.dart) |
| `P12` | Montagem das dependências e navegação protegida | [`lib/main.dart`](../lib/main.dart), [`lib/app/lost_and_found_app.dart`](../lib/app/lost_and_found_app.dart), `ItemListScreen` |

## `P10`: adaptador HTTP de objetos

`HttpItemRepository` implementa o contrato de domínio `ItemRepository` e traduz
as falhas do serviço em `ItemRepositoryException`, sem expor tipos de transporte
à apresentação.

| Operação | Requisição | Respostas tratadas |
| --- | --- | --- |
| `fetchItems()` | `GET {API_BASE_URL}/items`, sem token | `200` com arranjo JSON; `429` e demais status viram mensagens recuperáveis |
| `createItem(...)` | `POST {API_BASE_URL}/items` com `Authorization: Bearer <token>` | `201` conclui; `401` invalida o token e sinaliza `isUnauthorized`; `400`, `408`, `413` e `415` retornam `fieldErrors`; demais status viram mensagem recuperável |

Decisões relevantes:

- **Credencial por contrato mínimo.** O adaptador depende apenas de
  `SessionTokenProvider` ([`session_token_provider.dart`](../lib/features/auth/domain/session_token_provider.dart)),
  implementado por `HttpAuthRepository`. Ele envia o token e comunica a rejeição;
  não lê nem escreve o armazenamento seguro.
- **Autoria definida no servidor.** O corpo enviado contém apenas `name`,
  `description`, `location` e `status`; a autoria vem da sessão validada na API.
- **Sem repetição automática.** Um tempo esgotado ou uma falha de conexão não
  reenvia a requisição, para que uma gravação não seja persistida duas vezes. A
  nova tentativa é sempre uma ação do usuário.
- **Endereço público validado.** `ApiBaseUrl` ([`lib/core/api_base_url.dart`](../lib/core/api_base_url.dart))
  é compartilhado com o adaptador de autenticação: exige HTTPS (ou HTTP de
  loopback no desenvolvimento), recusa credenciais, consulta e fragmento na URL e
  preserva um caminho base configurado.
- **Ordenação normalizada.** A API já devolve `created_at DESC`; o adaptador
  reordena do mais recente para o mais antigo ao desserializar, de modo que a
  apresentação não dependa da ordem recebida.
- **Resposta inválida não vira conteúdo.** Campo ausente, tipo inesperado,
  situação desconhecida ou data e hora sem indicação de UTC são tratados como
  falha de protocolo, não como objeto parcial.

## `P11`: estado e tela da listagem

`ItemListNotifier` expõe `initial`, `loading`, `loaded` e `failed`, o conteúdo
imutável, a mensagem de erro e o indicador `savedItemAwaitingRefresh`.

- `load()` faz a primeira leitura; `refresh()` atende a atualização manual;
  `refreshAfterSave()` lê novamente após uma gravação confirmada.
- Uma leitura malsucedida **preserva** o conteúdo já carregado, para que uma
  falha de atualização não esvazie a lista que o usuário está consultando.
- Leituras repetidas enquanto uma está pendente não geram novas requisições;
  apenas `refreshAfterSave()` força uma leitura, invalidando a resposta anterior
  para que um retorno antigo não oculte o objeto recém-cadastrado.
- Respostas e falhas que chegam após o descarte são ignoradas, sem notificar.

`ItemListScreen` é a dona do notificador: cria no `initState`, inicia a leitura e
descarta no `dispose`. Os observadores são estreitos, conforme a revisão de
limites prevista no plano:

- o controle de atualizar observa somente o estado da leitura;
- a ação de sessão observa somente `AuthSessionNotifier`;
- o corpo observa o conteúdo da listagem;
- o botão flutuante não observa nenhum dos dois.

Estados visíveis: carregando (com texto), vazio utilizável com atualização e
atalho de cadastro, erro com **Tentar novamente**, e conteúdo com atualização por
arraste, barra de progresso durante a releitura e aviso de falha acima da lista.
Cada cartão mostra nome, situação, descrição, local e data e hora de criação. A
situação é identificada por rótulo (*Perdido* ou *Encontrado*), ícone e cor, sem
depender apenas da percepção de cores. A data e hora é formatada em
[`item_date_format.dart`](../lib/features/lost_found/presentation/item_date_format.dart),
convertendo o valor UTC para o fuso do dispositivo.

## `P12`: dependências e navegação

`main()` cria uma única `http.Client`, o `HttpAuthRepository` com armazenamento
seguro, o `HttpItemRepository` com o provedor de token e o `AuthSessionNotifier`,
e injeta tudo por construtor em `LostAndFoundApp`, que restaura a sessão sem
atrasar a listagem pública. Quando `API_BASE_URL` falta ou é inválido, o
aplicativo abre uma tela explicando a configuração em vez de encerrar sem aviso.

Regras de navegação:

| Situação | Comportamento |
| --- | --- |
| Cadastrar objeto sem sessão | Abre **Entrar**; ao entrar, segue para o formulário solicitado |
| Cancelar a entrada | Retorna à listagem pública, que continua consultável |
| Cadastrar objeto com sessão | Abre o formulário diretamente |
| Gravação confirmada | Mostra confirmação e atualiza a lista; o objeto aparece sem reiniciar |
| Gravação confirmada e atualização falha | Mantém a distinção em um aviso próprio; repetir atualiza apenas a leitura |
| Sessão rejeitada durante o envio | Marca a sessão como encerrada e abre **Entrar** sobre o formulário, preservando os dados digitados |
| Sair | Revoga o token no servidor, confirma e restaura a ação de entrar; a listagem é a única rota, então voltar não reabre ação protegida |

## Testes

```sh
flutter test test/features/lost_found/data/http_item_repository_test.dart
flutter test test/features/lost_found/presentation/item_list_notifier_test.dart
flutter test test/features/lost_found/presentation/item_list_screen_test.dart
flutter test test/app
```

| Verificação | Evidência |
| --- | --- |
| `A01` conteúdo e ordenação | `http_item_repository_test.dart` (ordenação e serialização), `item_list_screen_test.dart` (campos do cartão, rótulos e posição relativa) |
| `A02` lista vazia e atualização | `item_list_notifier_test.dart`, `item_list_screen_test.dart` |
| `A06` falha de leitura | `http_item_repository_test.dart` (tradução das falhas), `item_list_notifier_test.dart` e `item_list_screen_test.dart` (mensagem e nova tentativa) |
| `A08` gravação concluída e falha na atualização | `item_list_notifier_test.dart`, `test/app/navigation_flow_test.dart` |
| `A16` navegação protegida | `test/app/navigation_flow_test.dart` |

Os testes isolam a rede com `MockClient` e repositórios falsos; nenhum deles
acessa a API implantada. A verificação em dispositivo contra a API pública
permanece como evidência de execução a ser registrada na entrega.
