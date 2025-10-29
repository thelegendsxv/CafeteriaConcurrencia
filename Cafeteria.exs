defmodule Cafeteria do
  @capacidad 3

  def main do
    cafeteria = start(@capacidad)

    IO.puts("""
     Bienvenido a la cafetería
    Capacidad de máquinas: #{@capacidad}
    Comandos disponibles:
      - pedir (nombre) (bebida)
      - salir (nombre)
      - apagar
    Ejemplo: pedir Ana Capuccino
    """)

    loop_usuario(cafeteria)
  end

  defp loop_usuario(cafeteria) do
    comando =
      IO.gets("> ")
      |> String.trim()

    cond do
      comando == "apagar" ->
        send(cafeteria, :detener)
        IO.puts("Cerrando cafetería...")

      String.starts_with?(comando, "pedir ") ->
        case String.split(comando, " ") do
          ["pedir", nombre, bebida] ->
            nombre = String.downcase(nombre)
            send(cafeteria, {:nuevo_pedido, nombre, bebida})
            loop_usuario(cafeteria)

          _ ->
            IO.puts("Formato inválido. Usa: pedir <nombre> <bebida>")
            loop_usuario(cafeteria)
        end

      String.starts_with?(comando, "salir ") ->
        [_ , nombre] = String.split(comando, " ")
        nombre = String.downcase(nombre)
        send(cafeteria, {:salir, nombre})
        loop_usuario(cafeteria)

      true ->
        IO.puts("Comando no reconocido.")
        loop_usuario(cafeteria)
    end
  end

  # Inicia el proceso principal
  def start(capacidad) do
    spawn(fn -> loop(capacidad, 0, [], MapSet.new()) end)
  end

  defp loop(capacidad, ocupadas, espera, atendiendo) do
    receive do
      {:nuevo_pedido, nombre, bebida} ->
        cond do
          MapSet.member?(atendiendo, nombre) ->
            IO.puts(" #{String.capitalize(nombre)} ya tiene un pedido en preparación.")
            loop(capacidad, ocupadas, espera, atendiendo)

          ocupadas < capacidad ->
            IO.puts(" #{String.capitalize(nombre)} empieza a preparar un #{bebida}. (#{ocupadas + 1}/#{capacidad})")
            spawn(fn -> preparar(nombre, bebida, self()) end)
            loop(capacidad, ocupadas + 1, espera, MapSet.put(atendiendo, nombre))

          true ->
            IO.puts(" #{String.capitalize(nombre)} debe esperar, todas las máquinas están ocupadas. (#{ocupadas}/#{capacidad})")
            loop(capacidad, ocupadas, espera ++ [{nombre, bebida}], atendiendo)
        end

      {:pedido_listo, nombre} ->
        IO.puts(" #{String.capitalize(nombre)} terminó su pedido. (#{ocupadas - 1}/#{capacidad})")
        atendiendo = MapSet.delete(atendiendo, nombre)

        case espera do
          [{siguiente, bebida_siguiente} | resto] ->
            IO.puts(" #{String.capitalize(siguiente)} ahora puede preparar su #{bebida_siguiente}. (#{ocupadas}/#{capacidad})")
            spawn(fn -> preparar(siguiente, bebida_siguiente, self()) end)
            loop(capacidad, ocupadas, resto, MapSet.put(atendiendo, siguiente))

          [] ->
            loop(capacidad, ocupadas - 1, [], atendiendo)
        end

      {:salir, nombre} ->
        cond do
          MapSet.member?(atendiendo, nombre) ->
            IO.puts(" #{String.capitalize(nombre)} canceló su pedido. (#{ocupadas - 1}/#{capacidad})")
            atendiendo = MapSet.delete(atendiendo, nombre)

            case espera do
              [{siguiente, bebida_siguiente} | resto] ->
                IO.puts(" #{String.capitalize(siguiente)} ahora puede preparar su #{bebida_siguiente}. (#{ocupadas}/#{capacidad})")
                spawn(fn -> preparar(siguiente, bebida_siguiente, self()) end)
                loop(capacidad, ocupadas, resto, MapSet.put(atendiendo, siguiente))

              [] ->
                loop(capacidad, ocupadas - 1, [], atendiendo)
            end

          true ->
            IO.puts("#{String.capitalize(nombre)} no tiene pedido activo. (#{ocupadas}/#{capacidad})")
            loop(capacidad, ocupadas, espera, atendiendo)
        end

      :detener ->
        IO.puts(" Cafetería cerrada. ¡Hasta pronto!")
    end
  end

  defp preparar(nombre, bebida, cafeteria) do
    :timer.sleep(1000)
    IO.puts(" #{String.capitalize(nombre)} finalizó su #{bebida}.")
    send(cafeteria, {:pedido_listo, nombre})
  end
end

Cafeteria.main()
