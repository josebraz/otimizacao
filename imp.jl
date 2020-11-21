# Definições 

struct kLSF
  nV::Int                          # número de vértices totais
  nE::Int                          # número de arestas totais
  nL::Int                          # número de cores totais
  k_max::Int                       # máximo de cores que podem ser usadas na solução
  E::Dict{Int,Set{Tuple{Int,Int}}} # dicionario de arestas em que a chave é o vertice de partida e o valore é um conjunto de vertices destino e a cor da aresta
  
  zL::Set{Int}
  zE::Dict{Int,Set{Tuple{Int,Int}}}
end

################################################################
### Manipula a estrutura do grafo
function add_edge!(E::Dict{Int,Set{Tuple{Int,Int}}}, v1::Int, v2::Int, color::Int)
  E[v1] = push!(get(E, v1, Set()), (v2, color))
  E[v2] = push!(get(E, v2, Set()), (v1, color))
end

function add_edge!(input::kLSF, v1::Int, v2::Int, color::Int)
  input.E[v1] = push!(get(E, v1, Set()), (v2, color))
  input.E[v2] = push!(get(E, v2, Set()), (v1, color))
end
################################################################

################################################################
# conta quantas arvores tem na floresta para um grafo não direcionado
function count_trees(output::kLSF)::Int
  return count_trees(output.nV, output.E)
end

# conta quantas arvores tem na floresta para um grafo não direcionado
function count_trees_solution(output::kLSF)::Int
  return count_trees(output.nV, output.zE)
end

# conta quantas arvores tem na floresta para um grafo não direcionado
function count_trees(nV::Int, E::Dict{Int,Set{Tuple{Int,Int}}})::Int
  count = 0
  visited = falses(nV) # inicializa com nenhum vértice visitado
  for i=1:nV
    if visited[i] == false # se ainda não foi visitado, é o primeiro nodo da arvore
      count += 1           # incrementa o contador porque achamos mais uma arvore
      visit_neighbors!(i, visited, E)
    end 
  end
  return count
end

# marca como visitado o to_visit e todos os seus visinhos recursivamente
function visit_neighbors!(to_visit::Int, visited::BitArray, E::Dict{Int,Set{Tuple{Int,Int}}}) 
  visited[to_visit] = true
  for (i, color) in get(E, to_visit, Set())
    if (visited[i] == false)
      visit_neighbors!(i, visited, E)
    end
  end
end
################################################################

################################################################
### Conta as cores totais que tem nas arestas
function count_edge_colors(total_colors::Int, dict::Dict{Int,Set{Tuple{Int,Int}}})::Array{Int64}
  color_count = zeros(Int64, total_colors)
  for (v1, neighbors) in dict
    for (v2, color) in neighbors
      color_count[color] += 1
    end
  end
  return color_count
end

### retorna as k_max cores que mais aparecem no grafo
function greedy_edge_colors(input::kLSF)::Array{Int64}
  return sortperm(count_edge_colors(input.nL, input.E), rev=true)[1:input.k_max]
end

### retorna as k_max cores que mais aparecem no grafo
function greedy_edge_colors_solution(input::kLSF)::Array{Int64}
  return sortperm(count_edge_colors(input.nL, input.zE), rev=true)[1:input.k_max]
end

### cria um grafo com as arestas que tem as cores recebidas e nenhuma outra aresta
function create_graph_with_colors(input::kLSF, colors)::kLSF
  newE = Dict{Int,Set{Tuple{Int,Int}}}()
  for (v1, neighbors) in input.E
    for (v2, color) in neighbors
      if color in colors
        add_edge!(newE, v1, v2, color)
      end
    end
  end
  return kLSF(input.nV, input.nE, input.nL, input.k_max, input.E, Set(colors), newE)
end
################################################################

################################################################
# Faz o parser do arquivo de entrada colocando ele
# na estrutura esperado do nossa programa
function parse_test_file(file_name::String)::kLSF
  lines = readlines(file_name)
  nV, nE, nL, k_max = parse.(Int, split(lines[1]))
  E = Dict{Int,Set{Tuple{Int,Int}}}()
  for i = 3:length(lines)
  v1, v2, color = parse.(Int, split(lines[i]))
  add_edge!(E, v1, v2, color)
  end
  return kLSF(nV, nE, nL, k_max, E, Set(), Dict())
end
################################################################

################################################################
#### simulated annealing

# Gera vizinhos aleatórios no espaço de soluções
# desejável: simetria (ou reversível) e completa
# Ideia geral: pegar um cor que está no solução e trocar por uma cor que não está
# Complexidade:
function N(x::kLSF)::kLSF
  new_colors = Set(x.zL)

  new_colors = setdiff(new_colors, Set(rand(new_colors)))

  while length(new_colors) < length(x.zL)
    new_colors = push!(new_colors, rand(1:x.nL))
  end

  return create_graph_with_colors(x, new_colors)
end

# Cria uma solução válida inicial para ser melhorada com o algoritmo
# Ideia geral: tentar pegar as cores que aparecem mais
# para estarem na solução inicial (guloso)
# Complexidade:
function create_S0(input::kLSF)::kLSF
  zL = greedy_edge_colors(input)
  return create_graph_with_colors(input, zL)
end

# avalia uma solução e retorna o score dela
# quanto menor o valor, melhor é a solução (reduziu a energia)
# Complexidade:
function f(x::kLSF)::Int 
  return count_trees_solution(x)
end

function simulated_annealing(s0::kLSF, T0::Float64, r::Float64, STOP1::Int, STOP2::Int, STOP3::Int)::kLSF
  s = s0     # solução atual
  T = T0     # temperatura atual
  fs = f(s)  # avaliação da solução atual
  best = s   # melhor solução que esse algoritmo já viu
  fbest = fs # avaliação da melhor solução
  killer = 0 # execuções da metrópolis sem achar uma solução melhor que a atual 

  for i=1:STOP2
    killer += 1
    for j=1:STOP1
      sn = N(s)                        # gera novo vizinho 
      fsn = f(sn)                      # avalia novo vizinho gerado
      if fsn <= fs ||                  # se a nova solução é "melhor" OU
          rand() <= exp(-(fsn - fs)/T) # se caiu na questão da aleatoriedade
        s = sn                         # atualiza a nova solução
        fs = fsn                       # atualiza o valor da nova solução também
        if fs < fbest                  # se essa nova solução é a melhor já vista
          best = s                     # atualiza a melhor solução ja vista
          fbest = fs                   # atualiza a avaliação da melhor solução
          killer = 0
        end
      end   
    end
    if killer >= STOP3                 # atingiu o máximo de iterações sem achar uma solução melhor
      return best
    end
    T = T * r                          # atualiza a temparatura (diminui)
  end
  return best                          # retorna a melhor solução ja vista
end
################################################################

################################################################
## main
using Statistics
using Random

function main(args)
  if length(args) < 7
    println("Ajuda: Mínimo de 7 argumentos para essa implementação:")
	println("       1) T0    - Temperatura inicial (Float)")
	println("       2) r     - Decaimento da temperatura [0,1] (Float)")
	println("       3) k     - Número de execuções completas")
	println("       4) STOP1 - Número de iterações da metrópolis")
	println("       5) STOP2 - Número de iterações do simulated annealing")
	println("       6) STOP3 - Número de iterações máximas do simulated annealing sem achar uma solução melhor")
	println("     7..) files - Lista de arquivos que serão usados como instancias")
	return
  end
  
  T0    = parse(Float64, args[1])
  r     = parse(Float64, args[2])
  k     = parse(Int64, args[3])     # número de execuções
  STOP1 = parse(Int64, args[4])
  STOP2 = parse(Int64, args[5])
  STOP3 = parse(Int64, args[6])

  # para cada arquivo de entrada executa
  for file in args[7:end]
    input = parse_test_file(file)
    list_fs0 = zeros(k)
    list_fs = zeros(k)
    list_time = zeros(k)

    for i in 1:k
      Random.seed!(i)
	  
      list_time[i] = @elapsed begin
        s0 = create_S0(input)
        list_fs0[i] = f(s0)

        s = simulated_annealing(s0, T0, r, STOP1, STOP2, STOP3)
        list_fs[i] = f(s)
      end
	  
      println("Execução: ", i, " Resultado: ", list_fs[i])
    end

    mean_fs0 = mean(list_fs0)
    mean_fs = mean(list_fs)
    mean_time = mean(list_time)
    std_fs = std(list_fs)

    best_s = findmax(list_fs)[1]
    mean_percent_d = mean([100 * (s - best_s) / best_s for s in list_fs])

    println("file: ", file, " mean_fs0: ", mean_fs0, " mean_fs: ", mean_fs, " mean_time: ", mean_time, " std_fs: ", std_fs, " mean_percent_d: ", mean_percent_d)
  end
  
end

main(ARGS)
