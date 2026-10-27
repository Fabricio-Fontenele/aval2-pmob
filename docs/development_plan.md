# Achados e Perdidos: planejamento de desenvolvimento da equipe

## Referências, prazo e premissas

- Fonte de verdade para o comportamento da aplicação: [enunciado oficial](pmob-aval2.pdf).
- Ampliação solicitada: incluir cadastro de usuários e autenticação, além do
  cadastro de objetos. Essa ampliação não é exigida pelo PDF e não altera os
  critérios de pontuação nem o prazo oficial.
- Convenções de engenharia: [AGENTS.md](../AGENTS.md).
- Período do planejamento: de 27 de outubro a 8 de novembro de 2026.
- Prazo oficial: **08/11/2026, às 23h59**, com entrega exclusivamente pelo
  SIGAA, contendo o endereço do repositório público no GitHub e o nome completo
  de todos os integrantes (seção 8 do enunciado).
- Meta interna de entrega: **08/11, às 20h**. Utilizar o fuso
  America/Fortaleza no cronograma da equipe e confirmar o prazo no SIGAA.
- Equipe: **Fabricio, Francisco, Ruan e Willamy**. Ruan e Willamy são considerados
  integrantes distintos. Ainda é necessário reunir os nomes completos e as contas
  do GitHub.
- Situação atual: existem os requisitos e as instruções para agentes; ainda não há
  aplicação Flutter, manifesto de dependências ou serviço de nuvem configurado.
  O Git foi inicializado, e a documentação está publicada no repositório público
  [Fabricio-Fontenele/aval2-pmob](https://github.com/Fabricio-Fontenele/aval2-pmob),
  com a branch principal `main`.
- As datas são marcos propostos, sem pressupor a disponibilidade individual.
  Confirmar a disponibilidade na reunião inicial e redistribuir tarefas quando
  necessário, preservando o tempo reservado à integração e à verificação final.

Este documento planeja trabalho futuro. Ele não provisiona serviços, inicializa
o Git, cria código da aplicação nem autoriza agentes a executar commits, enviar
alterações ao remoto, publicar o projeto ou realizar a entrega.

## Entrega e escopo

Entregar um aplicativo móvel executável com quatro telas: listagem de objetos,
cadastro de objetos, entrada e cadastro de usuários. Os registros devem ser
compartilhados remotamente entre instalações e continuar disponíveis após o
encerramento do aplicativo. Utilizar objetos e contas demonstrativas, com
endereços de e-mail de teste e senhas exclusivas, sem informações pessoais reais.

| Critério de avaliação | Pontos | Evidência necessária | Responsáveis principais |
| --- | --- | --- | --- |
| Cadastro e validação | 2,0 | Campos obrigatórios; nome com até 60 caracteres; descrição com até 200 caracteres; local e situação; registro automático de data e hora | Willamy, com Fabricio na validação do domínio |
| Listagem e apresentação dos registros | 2,0 | Nome, local, situação e descrição; diferenciação entre perdido e encontrado; mais recentes primeiro; atualização manual | Ruan |
| Integração com armazenamento em nuvem | 2,0 | Leituras e gravações remotas reais; persistência após reiniciar; compartilhamento entre instalações; serviço gratuito funcionando | Francisco |
| Assincronismo e gerenciamento de estado | 2,0 | Carregamento, sucesso, falha, nova tentativa, proteção contra envios repetidos e atualização da lista após o cadastro | Fabricio coordena a integração; Ruan e Willamy cuidam dos respectivos notificadores |
| Interface, qualidade do código e organização do repositório | 2,0 | Material 3; interface em português; disposição responsiva; código formatado e sem problemas no analisador; repositório público e README completos | Fabricio coordena; todos contribuem |

Os cinco critérios têm o mesmo peso. Concluir o fluxo obrigatório completo antes
do refinamento visual. O cadastro de usuários e a autenticação passam a integrar
o escopo adicional solicitado, sem acrescentar pontuação à tabela oficial.
Edição, exclusão, fotos, notificações, pesquisa avançada e recursos nativos do
dispositivo continuam fora deste plano.

### Cadastro de usuários e autenticação

Os identificadores AU01-AU05 abaixo pertencem a este planejamento e não são
requisitos numerados pelo enunciado.

| ID | Comportamento planejado | Critério de aceite |
| --- | --- | --- |
| AU01 | Cadastro de usuário por e-mail e senha | E-mail obrigatório em formato válido; senha com pelo menos 8 caracteres, alinhada à política do provedor; confirmação de senha idêntica; carregamento, erro compreensível e proteção contra envio repetido |
| AU02 | Entrada por e-mail e senha | Campos obrigatórios; autenticação real no provedor; credenciais inválidas não abrem a sessão; falhas de comunicação permitem nova tentativa |
| AU03 | Sessão e saída | Restaurar a sessão pelo SDK ao iniciar, observar mudanças e renovação, tratar erros e permitir sair; a saída encerra o acesso às ações protegidas |
| AU04 | Autorização de publicação | Listagem e atualização permanecem públicas; cadastrar objetos exige sessão válida; o servidor rejeita inserções sem autenticação ou com autoria diferente do usuário autenticado |
| AU05 | Navegação e avaliação | Acesso às telas de entrada e criação de conta pela listagem; após entrar, retornar ao cadastro de objeto solicitado; cancelamento e saída mantêm a listagem acessível; avaliador consegue criar uma conta demonstrativa seguindo o README |

A confirmação de senha é apenas uma validação local e não é enviada ao serviço.
Normalizar o e-mail de forma consistente, sem modificar ou remover espaços da
senha. Deixar o gerenciamento de credenciais, persistência e renovação de sessão
com o SDK de autenticação. Não criar tabela própria de senhas, guardar senhas no
dispositivo nem registrar senhas ou tokens em mensagens e logs.

Para o ambiente demonstrativo, a proposta é desabilitar a confirmação de e-mail
no provedor e permitir entrada após o cadastro confirmado com sessão válida.
Registrar essa configuração no README e verificá-la na prova de viabilidade.
Isso mantém a avaliação independente do envio de mensagens para caixas pessoais.
No Supabase, a resposta de cadastro depende dessa configuração; usuário criado
sem sessão não significa usuário autenticado.
[Referência de cadastro](https://supabase.com/docs/reference/dart/auth-signup).

O serviço padrão de e-mail do Supabase restringe os destinatários sem SMTP
próprio. Se a equipe optar por exigir confirmação, deverá planejar e comprovar
entrega gratuita de e-mail, retorno ao aplicativo e tratamento da conta pendente
antes de alterar essa proposta.
[Referência de envio de e-mail](https://supabase.com/docs/guides/auth/auth-smtp).
Recuperação de senha, provedores sociais, telefone, autenticação multifator e
gestão de perfil não fazem parte desta ampliação.

## Responsabilidades e revisão

Cada integrante implementa código de produção, escreve os testes correspondentes,
contribui com commits identificáveis e conhece o fluxo completo de cadastro,
persistência na nuvem e exibição na lista. A revisão é compartilhada; nenhum
integrante fica responsável apenas pela documentação ou pelos testes manuais.

| Integrante | Responsabilidade de implementação | Responsabilidade adicional | Revisor principal |
| --- | --- | --- | --- |
| Fabricio | Estrutura inicial, entidades e contratos compartilhados, telas de entrada e criação de conta, estado da sessão, conexão das dependências e integração dos fluxos | Coordenar os marcos e a revisão do fluxo autenticado | Francisco |
| Francisco | Esquema e regras de acesso da nuvem, integração com autenticação, repositórios remotos, serialização e tratamento de erros do serviço | Documentar a configuração da nuvem e verificar a disponibilidade de dados e autenticação | Ruan |
| Ruan | Tela e notificador da listagem, cartões dos objetos, atualização manual, estados da lista e navegação entre consulta pública e ações protegidas | Consolidar o README com as contribuições dos demais | Willamy |
| Willamy | Tela e notificador de cadastro de objetos, validações do domínio e dos formulários, indicação de gravação e proteção contra envios repetidos | Coordenar o aceite final, incluindo contas demonstrativas, formulários e duas instalações | Fabricio |

Definir responsáveis por arquivo ajuda a evitar edições simultâneas. Combinar
previamente alterações nos contratos compartilhados, em `main.dart`, no manifesto
e no README. Cada responsável documenta sua configuração ou funcionalidade para
que Ruan consolide o conteúdo. Realizar uma conversa diária breve sobre
impedimentos e combinar a próxima entrega verificável. Integrar as telas durante
o desenvolvimento, sem deixar essa etapa para o último dia.

Cada integrante utiliza sua própria identidade de autor no Git e produz commits
coesos em inglês, seguindo Conventional Commits. Não fabricar contribuições nem
atribuir commits a outra pessoa. Não há uma estratégia obrigatória de branches.

## Base técnica e contratos iniciais

Utilizar Flutter/Dart, Material 3, `ChangeNotifier`, injeção por construtores e
`flutter_test`. Preferir a navegação do SDK e os componentes que observam
notificações de estado, salvo necessidade concreta de outra solução. Plataforma
proposta para desenvolvimento e verificação: Android; o enunciado exige um
aplicativo móvel, mas não determina uma plataforma específica. Confirmar a
disponibilidade de dispositivos na reunião inicial.

Organizar objetos em `lib/features/lost_found/` e autenticação em
`lib/features/auth/`, cada módulo com `domain/`, `data/` e `presentation/` conforme
a necessidade real. Espelhar os caminhos relevantes em `test/`. A inicialização,
o tema, a navegação e a montagem das dependências ficam fora desses módulos.
Criar diretórios e classes apenas quando houver conteúdo real; os módulos não
importam notificadores ou implementações de dados um do outro.

Fabricio disponibiliza os contratos compartilhados até 28/10, com a participação
dos outros três integrantes, para que interface e persistência avancem de forma
independente:

| Contrato | Definição |
| --- | --- |
| `LostFoundItem` | Propriedades imutáveis `id`, `name`, `description`, `location`, `status` e `createdAt`; Dart puro, sem tipos do SDK de nuvem |
| `ItemStatus` | Exatamente `lost` e `found`; rótulos apresentados em português |
| Validação do domínio | Rejeitar textos obrigatórios ausentes ou compostos apenas por espaços, nomes acima de 60 caracteres, descrições acima de 200 e situação ausente ou inválida; combinar contagem de caracteres e normalização consistentes |
| `ItemRepository.fetchItems()` | Retorna `Future<List<LostFoundItem>>`, com os mais recentes primeiro, ou uma falha documentada da aplicação |
| `ItemRepository.createItem(...)` | Recebe os quatro valores validados do formulário; retorna `Future<void>` após confirmar a persistência; os metadados de criação são atribuídos automaticamente |
| `ItemListNotifier` | Gerencia carregamento, dados, atualização e erros recuperáveis de leitura da lista |
| `ItemFormNotifier` | Gerencia progresso do envio, sucesso confirmado e erros recuperáveis de gravação; rejeita envios simultâneos |
| Resultado da navegação | Apenas uma gravação confirmada produz o resultado de sucesso que dispara a atualização da listagem |
| `AuthUser` | Identidade mínima do usuário, com `id` imutável em Dart puro; tipos de sessão e tokens do SDK permanecem na camada de dados |
| `AuthRepository` | Encapsula cadastro, entrada, saída, restauração e observação de sessão; traduz respostas e falhas do provedor para contratos em Dart puro |
| `AuthSessionNotifier` | Representa restauração inicial, sessão ativa, ausência de sessão e falha; publica apenas mudanças observáveis e libera a assinatura de eventos |
| Estado dos formulários de acesso | Progresso e erros de entrada e criação de conta ficam próximos de seus formulários; não provocam notificações globais a cada edição de campo |
| Autorização de cadastro de objeto | A navegação consulta a sessão; a camada de dados utiliza a identidade autenticada e o banco valida a autoria, sem confiar em um identificador informado pelo formulário |

Os dois repositórios correspondem a fronteiras distintas: objetos e autenticação.
Não acrescentar uma camada de casos de uso ou um notificador que concentre todo
o estado da aplicação. O notificador de sessão é compartilhado somente pelos
consumidores que precisam saber se há usuário autenticado. Os testes podem usar
implementações simuladas enquanto Francisco implementa os adaptadores remotos;
o aplicativo executável utiliza persistência e autenticação reais.

Observar os eventos de autenticação com tratamento de erros e cancelamento da
assinatura no descarte. Falhas de renovação por falta de rede devem ser tratadas
sem exceções não capturadas; quando a sessão deixar de ser válida, interromper
novas publicações e solicitar nova entrada, sem reenviar o formulário
automaticamente. Resultados antigos não podem restaurar uma sessão encerrada.
[Referência de eventos de autenticação](https://supabase.com/docs/reference/dart/auth-onauthstatechange).

### Serviço de nuvem proposto

**Recomendação sujeita à verificação inicial de viabilidade: Supabase Free com
PostgreSQL, Supabase Auth e `supabase_flutter`.** Essa opção reúne dados remotos,
autenticação e restrições em um serviço com cliente Flutter documentado. Nenhuma
conta ou projeto foi criado como parte deste planejamento. Consultar
[preços](https://supabase.com/pricing) e
[instalação para Flutter](https://supabase.com/docs/reference/dart/installing).

Francisco é responsável pela decisão do provedor e registra o resultado até 28/10:

1. Verificar se o plano gratuito vigente permite dados, cadastro de usuários e
   autenticação sem recursos pagos. Comprovar criação de conta, entrada, saída,
   leitura pública e inserção autenticada com a configuração do cliente móvel.
   Confirmar limites do serviço e a política de senha de pelo menos 8 caracteres.
   [Referência de política de senhas](https://supabase.com/docs/guides/auth/password-security).
2. Planejar uma única tabela `items`, com os quatro campos do formulário, um
   identificador gerado, data e hora de criação atribuídas pelo servidor e autoria
   técnica `created_by` vinculada à identidade no serviço de autenticação.
   Validar obrigatoriedade, limites e situação tanto no banco quanto no domínio.
   Consultar os registros pela data e hora de criação em ordem decrescente. As
   contas ficam sob gestão do Supabase Auth; não criar tabela pública de usuários
   ou exibir e-mails e dados de conta nos registros dos objetos.
3. Expor somente a tabela necessária pela API de dados. Habilitar a segurança em
   nível de linha, Row Level Security, e configurar explicitamente permissões e
   políticas para leitura compartilhada pelos papéis `anon` e `authenticated`.
   Conceder inserção apenas a `authenticated`, exigindo dados válidos e
   `created_by = auth.uid()`; negar inserção sem sessão, autoria forjada,
   alterações e exclusões. A leitura continua compartilhada, sem filtrar a lista
   apenas pelos objetos do usuário atual. Verificar as permissões pelo cliente
   de cada papel, sem utilizar uma sessão administrativa.
   [Referência de controle de acesso](https://supabase.com/docs/guides/database/postgres/row-level-security).
4. Fornecer o endereço do projeto e a chave publicável do cliente por configuração
   de execução documentada. Manter chaves secretas, chaves `service_role` e senhas
   do banco fora do repositório e do aplicativo. Chaves publicáveis são destinadas
   aos clientes; a autorização deve ser garantida pelas regras de acesso.
   [Referência de chaves de API](https://supabase.com/docs/guides/getting-started/api-keys).
5. Versionar o SQL necessário ao esquema e às regras de acesso e documentar como
   outro integrante ou avaliador configura e executa o aplicativo. Incluir as
   configurações de autenticação e os passos para criar uma conta demonstrativa,
   entrar e sair, sem publicar senhas ou depender de credenciais privadas da
   equipe. A avaliação não pode depender de arquivos locais privados de um
   desenvolvedor.

Se a verificação de viabilidade falhar, escolher outro serviço gratuito validado
até o mesmo marco, preservar o contrato de persistência e atualizar este plano
antes de construir uma interface dependente do provedor. Não implementar dois
provedores nem substituir a nuvem por persistência local. Conforme as condições
consultadas, o Supabase pausa projetos gratuitos após uma semana de inatividade;
incluir verificações de disponibilidade antes da entrega e durante a avaliação.
[Condições do plano gratuito](https://supabase.com/pricing).

## Pacotes de trabalho e cronograma

As datas abaixo são de 2026. Uma dependência indica que o contrato ou a entrega
correspondente deve estar disponível antes da conclusão da tarefa dependente;
o planejamento dos testes pode começar antes.

| ID | Prazo proposto | Responsável | Depende de | Entrega e evidência de conclusão |
| --- | --- | --- | --- | --- |
| P01 | 27/10 | Fabricio | Nenhuma | Estrutura mínima do Flutter, base visual Material 3, testes iniciais e regras para ignorar arquivos que não devem ser versionados; aplicativo inicia na plataforma combinada. O repositório GitHub e a configuração inicial do Git já estão disponíveis; a estrutura Flutter permanece pendente. |
| P02 | 28/10 | Fabricio e Willamy; todos revisam | P01 | Entidades, validações de objetos e acesso, contratos de persistência e autenticação e falhas combinadas; testes dos limites passam e os demais módulos conseguem utilizar os contratos. |
| P03 | 28/10 | Francisco | Definição dos contratos em P02 | Comprovação do serviço gratuito com dados e autenticação; leitura pública, cadastro de conta, entrada e inserção autenticada funcionam; política de confirmação e instruções iniciais registradas. |
| P04 | 30/10 | Francisco | P02, P03 | Adaptador de autenticação, esquema com autoria e regras de acesso; testes de tradução de falhas passam; requisições sem sessão e autoria forjada são negadas. |
| P05 | 01/11 | Francisco | P02, P03, P04 | Repositório de objetos conectado ao esquema e à sessão; testes de mapeamento e erros passam; registros permanecem após reiniciar o aplicativo. |
| P06 | 01/11 | Ruan | P01, P02 | Tela e notificador da listagem, cartões com campos obrigatórios, rótulos de situação, ordenação, atualização e testes dos estados públicos. |
| P07 | 01/11 | Willamy | P01, P02 | Tela e notificador de cadastro de objetos, validação, estado de gravação, nova tentativa e testes contra envios simultâneos. |
| P08 | 01/11 | Fabricio | P01, P02, P04 | Telas de entrada e cadastro de usuário, estado da sessão, saída e restauração; testes com falhas, credenciais inválidas e eventos de sessão passam. |
| P09 | 02/11 | Ruan; Fabricio apoia | P06, P07, P08 | Navegação entre listagem pública e cadastro protegido; entrada retorna à ação solicitada; saída bloqueia novas publicações sem interromper a consulta pública. |
| P10 | 03/11 | Fabricio; responsáveis pelos módulos apoiam | P04, P05, P06, P07, P08, P09 | Fluxo completo real: consultar, criar conta ou entrar, cadastrar objeto, persistir, retornar, atualizar e sair; testes de integração comprovam a navegação e o novo registro. |
| P11 | 05/11 | Cada responsável por módulo; Fabricio coordena | P10 | Falhas e novas tentativas, sessão expirada, descarte de recursos, observadores restritos, tela pequena, teclado e testes afetados concluídos. |
| P12 | 06/11 | Ruan; todos fornecem conteúdo | P03, P10 | README com nomes completos, escopo adicional, serviço de nuvem e autenticação, parâmetros públicos, configuração, execução e criação de conta demonstrativa. |
| P13 | 07/11 | Willamy coordena; todos participam | P11, P12 | Compilação e execução a partir de cópia limpa, contas distintas em duas instalações, regras de acesso, verificações finais de qualidade e histórico dos integrantes; registrar resultados e resolver impedimentos. |
| P14 | 08/11, às 20h | Fabricio; Francisco como substituto | P13 | Integrante autorizado envia o endereço do repositório e os nomes completos pelo SIGAA e confirma o comprovante antes do prazo oficial de 23h59. |

**Desenvolvimento paralelo:** após P02, listagem, cadastro de objetos e telas de
acesso avançam com os contratos combinados enquanto Francisco conclui os
adaptadores remotos. As interfaces usam implementações simuladas nos testes até
a integração com o serviço real. P03 antecipa os riscos de dados e autenticação.

**Marco de integração:** em 03/11, o fluxo real com cadastro de usuário,
autenticação e persistência remota deve estar funcionando. Encerrar a inclusão de
funcionalidades até 06/11. Reservar 07/11 e o tempo restante de 08/11 para
verificações, correções e entrega. A ampliação aumenta o trabalho da equipe;
redistribuir tarefas nas conversas diárias sem retirar requisitos do PDF.

**Caminho crítico:** contratos e viabilidade de dados e autenticação; adaptadores,
regras de autoria e quatro telas; navegação protegida e integração entre gravação
e atualização; execução independente e entrega. Se uma tarefa atrasar, trabalhar
em dupla com um integrante disponível e reduzir o refinamento opcional,
preservando o comportamento obrigatório e o tempo de verificação final.

## Matriz de aceite e testes

Aplicar TDD às implementações com comportamento testável: escrever e executar um
teste que falhe, implementar o mínimo para fazê-lo passar e refatorar mantendo
os testes passando. Cada responsável fornece testes unitários e de widgets do
seu módulo; Fabricio cuida do teste de integração entre telas. Isolar os serviços
externos nos testes unitários e de widgets. Executar separadamente as verificações
com a nuvem real, utilizando registros demonstrativos e anotando os resultados.

| Verificação | Condição observável de aprovação | Requisito | Responsável |
| --- | --- | --- | --- |
| A01: Conteúdo da lista | Cada registro mostra nome, local, situação e descrição; perdidos e encontrados têm diferenciação visual e rótulos legíveis; os mais recentes aparecem primeiro | RF01 | Ruan |
| A02: Lista vazia e atualização | O estado vazio é utilizável; a atualização manual busca mudanças remotas e indica progresso | RF01, RF03 | Ruan |
| A03: Validação dos campos | Campos obrigatórios vazios ou compostos apenas por espaços e situação ausente são rejeitados; limites de 60/200 caracteres passam e 61/201 falham; dados inválidos não são enviados | RF02 | Fabricio, Willamy |
| A04: Cadastro de objeto bem-sucedido | Com sessão válida, uma gravação persiste os campos, a data e hora automáticas e a autoria; o novo objeto aparece na lista sem reiniciar o aplicativo | RF02, RF04, AU04 | Willamy, Fabricio |
| A05: Toques repetidos | Acionamentos repetidos de salvar enquanto a primeira operação está pendente geram uma única chamada ao repositório; a indicação de gravação fica visível | RF03, RF04 | Willamy |
| A06: Falha de leitura | Uma leitura malsucedida apresenta erro compreensível e permite tentar novamente; a lista é recuperada após restabelecer a conexão | RF03 | Ruan |
| A07: Falha de gravação | Uma gravação malsucedida preserva os dados preenchidos, encerra o estado de envio, mostra erro compreensível e permite nova tentativa | RF03 | Willamy |
| A08: Gravação concluída e falha na atualização | A interface diferencia persistência confirmada de falha ao atualizar a lista; repetir a atualização não cria outro registro | RF02, RF03, RF04 | Fabricio |
| A09: Persistência e compartilhamento | Entrar e cadastrar objeto na instalação A, fechá-la e reabri-la; atualizar a instalação B com outro usuário ou sem sessão; ambas carregam o mesmo registro, sem restringir a leitura ao autor | RF05, AU04 | Ruan, Francisco |
| A10: Regras de acesso remoto | Leitura funciona sem sessão e com sessão; só usuário autenticado insere com autoria própria; inserção sem sessão, autoria forjada, dados inválidos, alterações e exclusões são negados pelo banco | RF05, AU04 | Francisco |
| A11: Interface e ciclo de vida | As quatro telas usam Material 3 e textos em português; tela pequena, ampliação de texto, teclado, navegação de retorno e descarte com operação pendente não causam transbordamento nem exceções | RNF01, RF04, AU01-AU05 | Willamy, Ruan |
| A12: Entrega reproduzível | Outro integrante compila e executa de uma cópia limpa, segue o README e cria sua conta demonstrativa; avalia o fluxo completo sem depender de arquivos privados, caixa de e-mail pessoal ou senha da equipe | Seções 7 e 8; AU05 | Francisco, Ruan |
| A13: Cadastro de usuário | E-mail inválido, senha com menos de 8 caracteres e confirmação divergente são rejeitados; conta válida é criada pelo serviço e só produz estado autenticado com sessão válida; conta já existente ou falha de rede mostra mensagem compreensível | AU01 | Fabricio, Willamy |
| A14: Entrada e saída | Credenciais válidas abrem sessão; inválidas não autenticam; sair encerra o acesso à publicação e mantém a lista pública disponível | AU02, AU03 | Fabricio |
| A15: Restauração e expiração | Reiniciar restaura sessão válida pelo SDK; falha de renovação é tratada; sessão inválida impede nova gravação e solicita entrada sem reenviar o objeto automaticamente | AU03, AU04 | Fabricio, Francisco |
| A16: Navegação protegida | Sem sessão, solicitar cadastro de objeto leva à entrada; entrar retorna à tela solicitada; cancelar permite consultar a lista; voltar após sair não reabre uma ação protegida | AU04, AU05 | Ruan |
| A17: Concorrência e descarte na autenticação | Toques repetidos geram uma única solicitação pendente; eventos ou respostas antigas após saída ou descarte não restauram sessão nem provocam atualização indevida | AU01-AU03 | Fabricio, Willamy |
| A18: Configuração e dados de conta | O cadastro funciona conforme a configuração de confirmação documentada; senha e confirmação não são persistidas pela aplicação, tokens não aparecem em logs e dados da conta não são expostos nos objetos | AU01, AU03, AU05 | Francisco, Willamy |

Em P11, revisar também os limites dos observadores de estado: o estado da lista
deve envolver o conteúdo da listagem; o estado de envio, apenas as mensagens e
o botão que dependem dele. Editar um campo não deve exigir notificações para a
tela inteira. Liberar os recursos e proteger conclusões assíncronas após a
navegação. Alterar e-mail, senha ou carregamento de um botão de acesso não deve
reconstruir a listagem. Observar a sessão apenas na navegação e nos controles que
dependem dela. Reconstruções normais do framework são aceitáveis; acrescentar
mecanismos de desempenho somente diante de um problema concreto.

Após alterações relevantes no código, executar `dart format .`, `flutter analyze`
e `flutter test`. Para a plataforma Android proposta, compilar localmente com
`flutter build apk --debug` e executar com `flutter run -d <device_id>`, utilizando
a configuração de nuvem documentada. Manter os resultados da compilação apenas
localmente. Registrar quais comandos e verificações manuais foram efetivamente
executados; dispositivo indisponível ou configuração malsucedida permanece como
impedimento explícito.

## Lista de verificação da entrega

- [ ] Os cinco critérios de avaliação têm evidências de atendimento, sem testes relevantes falhando.
- [ ] O escopo adicional AU01-AU05 foi validado: criar conta, entrar, restaurar sessão, publicar objeto e sair.
- [ ] Os quatro integrantes contribuíram com commits identificáveis e conseguem explicar o fluxo completo.
- [ ] O README contém os nomes completos de Fabricio, Francisco, Ruan e Willamy.
- [ ] O README distingue requisitos do PDF e ampliação solicitada, descreve os serviços gratuitos, pré-requisitos, configuração e execução e explica como criar uma conta demonstrativa.
- [ ] O endereço do projeto, a chave publicável do cliente e os demais parâmetros públicos necessários estão disponíveis nas instruções documentadas; não há credenciais privadas expostas.
- [ ] A configuração de autenticação, esquema, autoria e regras de acesso pode ser reproduzida, e os serviços utilizados na avaliação estão acessíveis.
- [ ] A política de confirmação de e-mail está documentada e o avaliador consegue criar conta e entrar sem credenciais privadas da equipe.
- [ ] Requisições sem sessão ou com autoria forjada são rejeitadas pelo servidor; consultas continuam compartilhadas entre instalações e usuários.
- [ ] Uma cópia limpa compila e executa; a persistência remota e o compartilhamento entre duas instalações funcionam.
- [ ] Os resultados reais da formatação, do analisador, dos testes e das verificações em dispositivo estão registrados.
- [ ] O repositório público no GitHub está acessível sem convite privado.
- [ ] Código-fonte, configurações e documentação estão presentes; não há APK/AAB/IPA, executáveis, `build/`, caches de ferramentas ou saídas geradas desnecessárias versionadas.
- [ ] Fabricio ou o substituto envia o endereço do repositório e os nomes completos pelo SIGAA e confirma o comprovante antes de 08/11, às 23h59.

O enunciado exige um repositório público com o código-fonte e a entrega pelo
SIGAA; não exige versionar nem publicar separadamente o binário do aplicativo.
A verificação da compilação é local, e os artefatos gerados ficam fora do Git.

## Decisões pendentes para o início

Resolver os pontos abaixo durante P01-P03, sem tratar premissas como trabalho
já concluído:

- Nome completo, conta do GitHub e disponibilidade de cada integrante para as
  datas propostas.
- Dispositivo ou emulador Android disponível e pré-requisitos do SDK em cada
  estação de trabalho.
- Provedor gratuito de nuvem após a verificação de viabilidade de Francisco;
  responsável pelo projeto e substituto com acesso para recuperar a disponibilidade
  dos serviços de dados e autenticação durante a avaliação.
- Confirmar a política proposta de leitura pública e publicação autenticada,
  a configuração demonstrativa sem confirmação de e-mail e a política de senha
  alinhada entre formulários e provedor.
- Responsabilidade pela entrega no SIGAA confirmada com Fabricio e Francisco,
  incluindo informações de prazo e fuso horário apresentadas pela disciplina.

Se o cronograma precisar mudar, atualizar os responsáveis e as datas dos marcos
em conjunto. Manter um responsável por entrega e preservar, sempre que possível,
a meta de integração em 03/11 e a reserva de tempo para a verificação final.
