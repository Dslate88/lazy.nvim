# Neovim Config and Customization
- Examples below. New config using lazy loading ecoystem, replacing my old packer based system that I used from 2021 to late 2025.
- Reason for Neovim custom config over VSCode:
  - By minimizing use of a mouse and having customized workflows I can execute to quickly explore and digest context for a given problem I am able to rapidly get feedback on logic in development.
  - Many activities are just a few keystrokes a way, and whats not I can write code to automate them in the event they are becomming patterns I repeat a lot. 

### Quick Find File

https://github.com/user-attachments/assets/8a78a34f-6581-4e64-aa7a-d1d02164b8d3

### Quick Search for all instances of a word

https://github.com/user-attachments/assets/403a9109-9f45-49b0-9bf3-d8b647508be4


### Custom LLM Plugin Example:
- For languages I am not familiar with, that are not production systems, using LLM's can be helpful.
- For instance, my keymap will format the active files, inject them as context with the goal I provide in the UI below.
<img width="1199" height="362" alt="image" src="https://github.com/user-attachments/assets/397968ef-34a3-4c6e-a2e3-75c581990c59" />

Example of the context builder via its logger 

<img width="612" height="760" alt="image" src="https://github.com/user-attachments/assets/132e3403-5355-4209-a42d-b314477db451" />

Output of this LLM assisted custom tool that I have mapped to trigger when I push `space`, followed by `a` + `r` and give it a goal:

<img width="1559" height="438" alt="image" src="https://github.com/user-attachments/assets/80576094-bf4c-432b-a825-3c1080ebc536" />

### LLM Philosophy:
- For production systems I am bearish on agentic systems as i've observed them generate tons of tech debt and over-engineered code.
  - [example](https://github.com/Dslate88/lazy.nvim/pull/1/files), I used LLM's to help me rapidly build my custom logic for this Neovim repo as I am not a lua developer. Despite my best efforts it created tech debt that snuck in...
  - [mlops-demo](https://github.com/Dslate88/mlops-aws-demo/issues/3) shows a pr history of me writing my own code due to the tech stack and language, python, being one I am proficient in. LLM workflows are still mapped to keys to kick off feedback scripts that catch any issues with my implementations of design patterns. Humans also make mistakes, let LLM's quickly inform you when you make them!
