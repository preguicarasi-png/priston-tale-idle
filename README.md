# Priston Tale Idle 3D — Godot 4.7

Projeto de idle RPG 3D para Godot, preparado para usar **localmente** os arquivos de Priston Tale que você já possui.

> Os assets originais não ficam neste repositório. O importador converte os arquivos que já estão no seu PC para GLB dentro de `assets/imported/`.

## O que já está no projeto

- jogo 3D com câmera alta estilo MMORPG;
- personagem corre automaticamente até o inimigo;
- ataques automáticos, crítico, morte e respawn;
- tentativa automática de tocar animações Idle/Walk/Run/Attack/Die dos modelos importados;
- Ice Goblin / D_Magi / outros monstros importados;
- level máximo 60 e curva de EXP lenta;
- bosses periódicos;
- ouro, drops, inventário e equipamentos;
- troca de armadura por modelos reais convertidos do `tmABCD`;
- armas reais convertidas da pasta de weapons;
- miniaturas 3D dos próprios itens no inventário;
- quests, mapas, torre, dungeon e ranking local;
- save e progresso offline;
- tela inicial/criação de personagem baseada nas variantes importadas.

## 1. Instalar o conversor

O projeto usa o conversor aberto **3dAssetExporter**:
https://github.com/wesleyricardi/3dAssetExporter

No Windows, execute:

`tools\PREPARAR_CONVERSOR.bat`

O script clona o conversor e tenta compilar com MSBuild/Visual Studio Build Tools.

Se a compilação automática não funcionar, abra o projeto do 3dAssetExporter no Visual Studio e compile em DebugClient. Depois informe o caminho do `AssetExporter.exe` ao importador.

## 2. Importar seus arquivos do Priston

Execute:

`tools\IMPORTAR_PRISTON.bat`

Informe a pasta raiz onde estão suas pastas, por exemplo:

- `char\tmABCD`
- `char\monster\icegoblin`
- `char\monster\d_magi`
- `weapons`

O script procura automaticamente INX/SMD relevantes e gera GLBs em:

`assets\imported\`

Nenhum arquivo original é enviado ao GitHub.

## 3. Abrir no Godot

1. Abra o Godot 4.7.2.
2. Importe o arquivo `project.godot`.
3. Aguarde o Godot importar os GLBs.
4. Aperte **F5**.

Se nenhum asset tiver sido importado, o jogo abre uma tela explicando o que falta em vez de mostrar os antigos bonecos improvisados.

## 4. Exportar para Windows

No Godot:
`Projeto > Exportar > Windows Desktop > Exportar Projeto`

## 5. Android

O preset Android está incluído, mas o PC precisa de JDK 17 + Android SDK configurados no Godot.

---
Este projeto não distribui os assets proprietários de Priston Tale e não é afiliado aos titulares do jogo.
