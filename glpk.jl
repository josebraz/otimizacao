struct kLSF
  nV::Int                 # número de vértices totais
  nE::Int                 # número de arestas totais
  nL::Int                 # número de cores totais
  k_max::Int              # máximo de cores que podem ser usadas na solução
  E::Set{Tuple{Int,Int}}  # dicionario de arestas do grafo original em que a chave é o vertice de partida e o valore é um conjunto de vertices destino e a cor da aresta
  L::Dict{Tuple{Int,Int},Int}  # entra uma arest u v e sai a cor dela
end

################################################################
# Faz o parser do arquivo de entrada colocando ele
# na estrutura esperado do nossa programa
function parse_test_file(file_name::String)::kLSF
  lines = readlines(file_name)
  nV, nE, nL, k_max = parse.(Int, split(lines[1]))
  E = Set{Tuple{Int,Int}}()
  L = Dict{Tuple{Int,Int},Int}()
  for i=3:length(lines)
    v1, v2, color = parse.(Int, split(lines[i]))
	
	E = push!(E, (v1, v2))
	E = push!(E, (v2, v1))
	L[(v1, v2)] = color
	L[(v2, v1)] = color
	
  end
  return kLSF(nV, nE, nL, k_max, E, L)
end
################################################################

################################################################
function count_trees(s)::Int
  count = 0
  visited = falses(size(s,1)) # inicializa com nenhum vértice visitado
  for i=1:size(s,1)
    if visited[i] == false # se ainda não foi visitado, é o primeiro nodo da arvore
      count += 1           # incrementa o contador porque achamos mais uma arvore
      visit_neighbors!(i, visited, s)
    end 
  end
  return count
end

# marca como visitado o to_visit e todos os seus visinhos recursivamente
function visit_neighbors!(to_visit::Int, visited::BitArray, s) 
  visited[to_visit] = true
  for (index, value) in enumerate(s[to_visit,:])
    if (value == 1.0 && visited[index] == false)
      visit_neighbors!(index, visited, s)
    end
  end
end
################################################################

using JuMP
using GLPK
using Combinatorics

function main(args)

  # para cada arquivo de entrada executa
  for file in args[1:end]
    
	global input = parse_test_file(file)
	
    model = Model(GLPK.Optimizer)
 
    @variable(model, z[1:input.nL], Bin)
	@variable(model, x[1:input.nV,1:input.nV], Bin)
	
	@objective(model, Max, sum(x))
	
	for S in powerset(1:input.nV) 
	  if length(S) >= 3
		s = [(u,v) for (u,v) in combinations(S,2) if issubset(Set([(u,v)]), input.E)]
		if (length(s) > 0)
	      @constraint(model, sum([x[u,v] for (u,v) in s]) <= length(S) - 1)
		end
	  end
	end
	
	for (u,v) in input.E
	  @constraint(model, x[u,v] <= z[input.L[(u,v)]])
	end
	
	for u in 1:input.nV
	  for v in 1:input.nV
  	    if (!issubset(Set([(u,v)]), input.E))
	      @constraint(model, x[u,v] == 0)
	    end
	  end
	end
	
	@constraint(model, sum(z) <= input.k_max)
	
	optimize!(model)
	
	println("Arvores na solução: ", count_trees(value.(x)))
	
  end
  
end

main(ARGS)