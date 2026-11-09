# Achados e Perdidos — Campus Universitário

Aplicativo móvel desenvolvido em Flutter e Dart para divulgação e consulta de objetos perdidos e encontrados na comunidade acadêmica, correspondente à **2ª Avaliação da disciplina de Programação para Dispositivos Móveis** da **Universidade Estadual do Piauí (UESPI)**.

Professor: **Eyder Rios**

Repositório público: [Fabricio-Fontenele/aval2-pmob](https://github.com/Fabricio-Fontenele/aval2-pmob)

---

## Integrantes da Equipe

* **Fabrício Fontenele Vieira**
* **Francisco Alves Ribeiro Neto**
* **Ruan Pedro de Araújo Anjos**
* **Willamy Josué Santos Serejo**

---

## Funcionalidades da Aplicação

### 1. Listagem de Objetos (`RF01`)
* **Consulta em tempo real:** Carrega os registros persistidos remotamente na nuvem.
* **Ordenação cronológica:** Apresenta sempre os registros mais recentes primeiro (`created_at DESC`).
* **Identificação visual de situação:** Distinção nítida entre objetos **Perdidos** e **Encontrados** por meio de cores, cartões e badges informativos.
* **Informações completas:** Exibição clara do nome do objeto, local, situação e descrição detalhada.
* **Atualização manual:** Suporte a gesto *pull-to-refresh* e botão de recarregar a listagem.

### 2. Cadastro de Objetos (`RF02`)
* Formulário intuitivo com validação rigorosa dos campos antes do envio:
  * **Nome do objeto:** Obrigatório, com limite de até 60 caracteres.
  * **Descrição:** Obrigatória, com limite de até 200 caracteres.
  * **Local:** Obrigatório (rejeita entradas em branco ou apenas com espaços).
  * **Situação:** Seleção obrigatória entre *Perdido* ou *Encontrado*.
* **Data e hora automáticas:** O servidor atribui automaticamente o carimbo de data e hora do registro no momento da inserção.
* **Reflexo imediato:** Após a conclusão do cadastro, a listagem é atualizada e o novo item passa a encabeçar a lista.

### 3. Assincronismo e Gerenciamento de Estado (`RF03` e `RF04`)
* **Feedback de processamento:** Indicador de carregamento durante operações assíncronas de leitura e gravação.
* **Proteção contra envio duplicado:** O botão de envio é desabilitado durante o salvamento para evitar múltiplos cadastros simultâneos.
* **Tratamento de falhas:** Mensagens amigáveis em português em caso de indisponibilidade de rede ou falha no servidor, com botão **"Tentar novamente"**.
* **Gestão de estados explícita:** Tratamento visual para os estados de *carregando*, *lista vazia*, *sucesso* e *erro*.

### 4. Autenticação Demonstrativa (Escopo Adicional)
* Para atribuir autoria rastreável às publicações, o aplicativo conta com um módulo de autenticação próprio (API Dart independente com hash de senha em Argon2id e sessões em PostgreSQL). A consulta à lista é pública, enquanto o cadastro solicita login.

---

## Armazenamento em Nuvem (`RF05`)

O sistema utiliza serviços gratuitos na nuvem, com persistência durável dos dados após o encerramento do app e compartilhamento entre diferentes dispositivos:

* **Backend / API REST:** Desenvolvida em Dart (Shelf), conteinerizada via Docker e hospedada no **Render** (Plano Free com TLS/HTTPS).
  * **URL Base da API:** `https://campus-lost-found-api-zv3r.onrender.com`
  * **Health Check:** `https://campus-lost-found-api-zv3r.onrender.com/health`
  * **Endpoint Público de Itens:** `https://campus-lost-found-api-zv3r.onrender.com/items`
* **Banco de Dados Relacional:** **PostgreSQL** hospedado na nuvem via **Supabase** (Plano Free), garantindo armazenamento persistente e seguro.

---

## Guia de Execução e Avaliação

### 1. Como executar a aplicação Flutter

Com o Flutter instalado no ambiente, execute no terminal a partir da raiz do projeto:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://campus-lost-found-api-zv3r.onrender.com
```

*(Opcional: para gerar o APK de teste no Android: `flutter build apk --debug --dart-define=API_BASE_URL=https://campus-lost-found-api-zv3r.onrender.com`)*.

### 2. Acesso para Avaliação

Para facilitar a correção pelo avaliador, deixamos uma conta demonstrativa já ativa no banco da nuvem:

* **E-mail:** `avaliador@uespi.br`
* **Senha:** `SenhaAvaliador123`

> **Nota:** Caso prefira, o avaliador pode criar uma conta nova diretamente na tela do aplicativo clicando em **"Criar uma conta"** (não é necessária confirmação por e-mail; o acesso é imediato).

> **Aviso sobre o plano gratuito (Cold Start):** Como a API utiliza a camada gratuita do Render, o servidor pode entrar em repouso após períodos sem uso. A primeira requisição pode levar de 30 a 50 segundos para despertar o contêiner. Caso ocorra timeout inicial, basta utilizar a ação **"Tentar novamente"**.

---

## Verificação de Qualidade e Testes

O projeto segue as diretrizes do Material 3, Clean Architecture e convenções do Dart/Flutter:

```bash
# Formatação de código
dart format .

# Análise estática (deve retornar 0 problemas)
flutter analyze

# Execução da suíte de testes automatizados
flutter test
```
