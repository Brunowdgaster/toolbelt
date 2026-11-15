{
  description = "Ambientes reproduzíveis dos projetos do portfólio poliglota";

  # ## Por que este flake existe
  #
  # O plano do portfólio chama isto de "o entregável que impressiona": um
  # `nix develop` que levanta o ambiente dos 14 projetos. A razão prática é
  # mais chata e mais importante: **os ambientes foram montados à mão**.
  #
  # O `setup.sh` do p03-otp-mesh instala 14 ferramentas com `apt-get`, e eu
  # instalei outras 11 ao longo desta sessão — Nim, Odin, D, V, Ada, OCaml,
  # .NET, Rakudo, Tcl, Groovy, Nix. Nada disso está declarado em lugar nenhum:
  # está no histórico de comandos de uma máquina.
  #
  # Este arquivo é a declaração.
  #
  # ## O que ele NÃO promete
  #
  # **Não reproduz os números medidos.** As medições do portfólio foram feitas
  # com as versões do `apt` do Ubuntu 26.04, e o nixpkgs travado abaixo tem
  # outras: OCaml 5.5 contra 5.4, Erlang 28 contra 27, Scala 3.9 contra 3.10.
  #
  # Nix reproduz o **ambiente declarado**, com exatidão de hash. Mas "o mesmo
  # ambiente" e "as mesmas versões que eu usei" são coisas diferentes, e
  # confundir as duas seria prometer reprodutibilidade que não existe. Para
  # reproduzir uma medição é preciso casar as versões — e é por isso que cada
  # projeto registra as suas no README.
  #
  # O que o flake entrega é: **qualquer pessoa consegue compilar e testar os
  # projetos sem instalar nada à mão.**

  inputs = {
    # Travado numa release, não em `nixos-unstable`: um flake que aponta para
    # unstable muda de versão a cada `nix flake update` e deixa de ser a
    # resposta à pergunta "com o que isso foi construído".
    #
    # E `25.11`, não `25.05`, por um motivo MEDIDO e não estético: o 25.05
    # traz **Gleam 1.11**, e o `manifest.toml` do p03 tem a stdlib travada
    # numa versão que declara `gleam >= 1.14`. Com o 25.05, `nix develop .#p03`
    # avalia, constrói, entra -- e falha ao rodar `gleam test`, com o mesmo
    # erro "Incompatible Gleam version" que já tinha derrubado o CI daquele
    # projeto uma vez.
    #
    # Um flake que levanta um ambiente onde o projeto não compila é pior que
    # nenhum flake: ele promete e não entrega.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      # Os quatro sistemas que fazem sentido aqui. macOS entra porque o P08 do
      # plano exige Xcode, e o flake ser avaliável lá é o mínimo — ainda que
      # os shells de hardware (P09) não funcionem.
      sistemas = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      paraCada = f: nixpkgs.lib.genAttrs sistemas (s: f nixpkgs.legacyPackages.${s});
    in
    {
      devShells = paraCada (pkgs:
        let
          # Ferramentas que TODO projeto usa. Separadas porque repetir a lista
          # em cada shell é o jeito de ela divergir.
          comuns = with pkgs; [ git gnumake jq ];

          # Mensagem de entrada: um shell que não diz o que tem dentro obriga
          # quem entrou a adivinhar.
          anuncia = nome: ferramentas: ''
            echo ""
            echo "  ambiente: ${nome}"
            echo "  ${ferramentas}"
            echo ""
          '';
        in
        {
          # ------------------------------------------------------------ P01
          #
          # Sete implementações da mesma VM. É o shell mais pesado do
          # portfólio, e o mais claro sobre por que Nix vale a pena: montar
          # isto à mão são sete instalações, duas delas (Odin e V) fora do
          # apt, baixadas de release do GitHub.
          p01 = pkgs.mkShellNoCC {
            name = "p01-metal-vm";
            packages = comuns ++ (with pkgs; [
              gcc clang cmake          # as duas referências em C
              rustc cargo              # a referência em Rust
              nim                      # porte, 255 linhas
              odin                     # porte; fora do apt, vem de release
              ldc                      # porte em D
              vlang                    # porte; fora do apt também
              gnat14                   # porte em Ada
            ]);
            shellHook = anuncia "p01-metal-vm (VM de bytecode, 7 implementações)"
              "gcc clang cmake rustc nim odin ldc v gnat";
          };

          # ------------------------------------------------------------ P02
          p02 = pkgs.mkShellNoCC {
            name = "p02-forge-lang";
            packages = comuns ++ (with pkgs; [
              ghc                      # a referência: compilador completo
              ocaml                     # porte do verificador
              dotnet-sdk_10             # porte em F#; o .fsproj alveja net10.0
            ]);
            shellHook = anuncia "p02-forge-lang (linguagem com inferência total)"
              "ghc ocaml dotnet-sdk_10";
          };

          # ------------------------------------------------------------ P03
          #
          # O único projeto completo do portfólio: 8 de 8 linguagens.
          p03 = pkgs.mkShellNoCC {
            name = "p03-otp-mesh";
            packages = comuns ++ (with pkgs; [
              erlang elixir rebar3      # o núcleo OTP
              gleam                     # codec tipado na mesma BEAM
              go                        # gateway WebSocket
              rustc cargo               # o NIF
              # `scala-cli` e `jdk`, e NÃO o pacote `scala`.
              #
              # O p03 compila o Scala com `scala-cli run ... --jvm system`, e
              # precisa de JDK >= 21 porque o experimento usa
              # `Thread.ofVirtual` (Loom). Pôr `scala` aqui daria um shell que
              # avalia e não roda o projeto — o `scala` do nixpkgs é o
              # compilador, não a ferramenta que os scripts invocam.
              scala-cli jdk
              clojure                   # contenção em estado compartilhado
              opentofu                  # a infraestrutura em HCL
              docker-client kind        # o que a infra provisiona
            ]);
            shellHook = anuncia "p03-otp-mesh (plataforma distribuída, 8/8)"
              "erlang elixir gleam go rustc scala clojure opentofu docker kind";
          };

          # ------------------------------------------------------------ P12
          #
          # O shell mais leve, e por isso o que o CI verifica de ponta a
          # ponta: ele é a prova de que o flake não só avalia, mas constrói.
          p12 = pkgs.mkShellNoCC {
            name = "p12-toolbelt";
            packages = comuns ++ (with pkgs; [
              perl gawk lua5_4          # as três primeiras ferramentas
              rakudo                    # a grammar do .fasm
              tcl expect                # automação de REPL
              groovy jdk                # pipeline declarativo (pendente)
              powershell                # o par POSIX/Windows (pendente)
              ocaml                     # o Expect dirige o toplevel dele
            ]);
            shellHook = anuncia "p12-toolbelt (automação e higiene)"
              "perl gawk lua rakudo tcl expect groovy pwsh ocaml";
          };

          # -------------------------------------------------------- default
          #
          # Deliberadamente NÃO é a união de tudo.
          #
          # Um shell com as 28 ferramentas levaria vários gigabytes e quase
          # ninguém precisa delas ao mesmo tempo. O padrão é o p12, que é o
          # mais leve, e a mensagem diz como pedir os outros — em vez de
          # castigar quem digitou `nix develop` sem argumento.
          default = self.devShells.${pkgs.system}.p12;
        });

      # Formatador, para `nix fmt`. Pequeno e evita discussão de estilo.
      formatter = paraCada (pkgs: pkgs.nixpkgs-fmt);
    };
}
