load 'D:/osadka/interpolation.rb'
load 'D:/osadka/alfa.rb'
load 'D:/osadka/transpRoundMatrix.rb'
require 'prawn'
require 'prawn/table'

class IGE
	include Sigma_calculation
	attr_accessor :h, :z1, :z2, :u, :s, :s_zpi, :σzg, :e, :ei, :s_zgi, :s_add, :s_all  # разрешаем работу с полем h на чтение и запись
	attr_reader :waterHold, :gamma, :gamma_s, :e_por
	def initialize (h, gamma, waterHold, e, ei = 5*e, gamma_s = 2.7, e_por = 0.8)
		@h = h
		@gamma = gamma
		@waterHold = waterHold
		@e = e
		@ei = ei
		@z1 = z1; @z2 = z2;  @e_por = e_por; @gamma_s = gamma_s
		@u = 0; @σzg = 0; @s_zpi = 0; @s_zgi=0 
		@s = 0; @s_add = 0; @s_all # осадки
	end
	def newH h
		ret = self.dup
		ret.h = h
		ret
	end
end
class Ige_layers

	attr_reader :hc, :listLayers
	def initialize(listLayers)
		@listLayers = listLayers
		@hc = nil
		@hc_7 = nil
	end
	def splitLayers(b)
		@b = b
		list_collect = []
		@listLayers.each do | elem |
			n = (elem.h / b).floor # целая часть от деления
			m =  elem.h % b # остаток
			n.times { | i | c = elem.dup; c.h = b; list_collect << c} 
			# здесь мы копируем слой, изменяя его запись h, и накапливая слои в list_collect
			if m != 0.0 then c = elem.dup; c.h = m; list_collect << c; end 
		end
		@listLayers = list_collect
	end
	def z_create
		z1 = 0
		@listLayers.each{|elem| elem.z1 = z1; elem.z2 = z1 + elem.h; z1 += elem.h}
	end
	def sigma_eval(p, sigma_zg0, b, bk, etta, etta_k)# надо вычислить напряжения
		if etta > 5 then etta = 5; puts "etta > 5, может считать ленточный фундамент? " end
		if etta_k > 5 then etta_k = 5; puts "etta_k > 5, может считать ленточный фундамент? " end
		prevWaterPress = 0; prev_σzg = sigma_zg0
		@listLayers.each{|elem| elem.s_zpi_method(p, b, etta); elem.s_z_gamma_i(sigma_zg0, bk, etta_k); m = elem.s_gi(prevWaterPress, prev_σzg); 
						prev_σzg = m[0]; prevWaterPress = m[1] }
	end
	def hc_eval(hMin)
		@listLayers.each do |elem| 
			if (elem.s_zpi < (0.5 * elem.σzg)) and (elem.z2 > hMin) then @hc = elem.z2; break end
		end
		if @hc == nil then @hc = " не достигнута" end
		@hc
	end
	def hc_7
		# метод ищет слабый слой с Е < 700 тс/м2 для корректировки сжатой толщи и расчета осадки
		@listLayers.each do |elem|
			if elem.z2 > @hc then 
				if elem.e < 700 then @hc_7 = elem.z2 end
			end
		end
		@hc_7
	end
	def hc_eval_7 (hMin)
		@listLayers.each do |elem| 
			if (elem.s_zpi < (0.2 * elem.σzg)) and (elem.z2 > hMin) then @hc = elem.z2; break end
		end
		@hc = [@hc, @hc_7].min
		@hc
	end
	def osadka_eval(s_formula)
		@listLayers.each{|elem| if elem.z1 < @hc then
		elem.s = s_formula.call(elem.s_zpi, elem.h, elem.e, elem.ei, elem.s_zgi)
		end
		}
	end
end
class SqBase
	attr_accessor :b_split, :listLayers, :x, :y, :l, :b, :sign, :plist
	attr_reader :sigma_zg0, :p_sr, :b_k, :l_k, :hMin, :loads, :name
	def initialize (name, l, b, h, h_landing, gamma_, loads, l_k = l + 1, b_k = b + 1, x = 0, y = 0)
		@name = name; @l = l; @b = b; @h = h; @h_landing = h_landing; @gamma_ = gamma_; @loads = loads; @l_k = l_k; @b_k = b_k
		@b_split = 0.4*@b
		@a = @b*@l
		@weight = 2
		@p_sr = @loads[:nmax] / @a + @weight * @h_landing # очень примерно вес считается
		@sigma_zg0 = @gamma_ * @h_landing
		# здесь длинное условие h_min должно быть
		if @b <= 10 then @hMin = @b/2 end
		if @b > 60 then @hMin = 10 end
		if (10 < @b) & (@b <= 60) then @hMin = 4 + 0.1*@b end 
		@listLayers = nil
		@x = x; @y = y
		@sign = nil # используется для задания знака влияющих фундаментов
		dx = (self.x - fund1.x).abs
		dy = (fund2.y - fund1.y).abs
		@plist = nil # point list - пригодится при вычислении влияющих фундаментов
	end
	def xy x, y
		@x = x; @y = y
	end
end

class Osadka
	include TranspMatrix
	def initialize listLayers, fundObj
	puts "Расчет фундамента #{fundObj.name}"
	ig_layers1 = Ige_layers.new(listLayers)


	ig_layers1.splitLayers(fundObj.b_split)
	ig_layers1.z_create

	# а теперь непосредственно определим формулу по которой будем считать (ввиде прока)
	if fundObj.p_sr > fundObj.sigma_zg0 
			s = Proc.new{ |s_zpi, h, e, ei, s_zgi| 
				s = 0.8*(s_zpi - s_zgi)*h/e + 0.8*s_zgi*h/ei
			}
		else
			s = Proc.new{ |s_zpi, h, e|
				s = 0.8 * s_zpi * h / e 
			}
		end
	# давление будем определять по координате z2
	p = fundObj.p_sr; sigma_zg0 = fundObj.sigma_zg0; b = fundObj.b; bk = fundObj.b_k; l = fundObj.l; lk = fundObj.l_k
	etta = l/b; etta_k = lk/bk
	ig_layers1.sigma_eval(p, sigma_zg0, b, bk, etta, etta_k)
	# теоретически напряжения уже посчитаны,
	# а теперь определим предельную толщу осадочную
	ig_layers1.hc_eval(fundObj.hMin)
	#проверим есть ли слабый слой
	hc_7 = ig_layers1.hc_7
	if hc_7 != nil then ig_layers1.hc_eval_7(fundObj.hMin) end
	
	# посчитаем осадку
	ig_layers1.osadka_eval(s)
	# выведем все в pdf-ку
	# -----------------------------------------------------------------------------------------------------------------------------------
	layersH = []; gamma_list=[]; eList=[]; wList=[]; γs_list =[]; e_por_list = []
	listLayers.each{|elem| layersH << elem.h; gamma_list << elem.gamma; eList << elem.e; wList << elem.waterHold; γs_list << elem.gamma_s; e_por_list << elem.e_por}
	m1 = self.transp [layersH, gamma_list, eList, wList, γs_list, e_por_list]
	m1 = [["H, м", "γ, т/м3","E, тс/м2", "Водонасыщенный, 'yes/no'", "γ_s - частиц грунта ", "к-т пористости"]] + m1
	z2List = []; σzpi_list = []; σ_zgi_list = []; σzgList = []; s_list = []
	ig_layers1.listLayers.each{|elem|  z2List << elem.z2; σzpi_list << elem.s_zpi;  σ_zgi_list << elem.s_zgi; σzgList << elem.σzg; s_list<<elem.s}
	m2 = self.transp [z2List, σzpi_list,  σ_zgi_list, σzgList, s_list]
	m2 = self.roundMatrix(m2, 5)
	m2 = [["z от центра фундамента в м", "σ_zpi, тм/м2 (от внешней нагрузки)", "σ_zγi, тм/м2 (от веса котлована)", "σzgi, тс/м2 (от с.в. грунтов)", "S - осадка, м"]] + m2
	s_all = 0.0
	ig_layers1.listLayers.each{|elem| s_all += elem.s}
	#puts m1.to_s
	Prawn::Document.generate("осадка #{fundObj.name} (без учета влияния соседних).pdf") do
		font("./fonts/times.ttf") do
			text "Нагрузки на фундамент #{fundObj.name}"
			t = make_table([[ "Nmax, тс", "Q1, тс", "Q2, тс", "M1, тс*м", "M2, тс*м"],
			[ fundObj.loads[:nmax], fundObj.loads[:q1], fundObj.loads[:q2], fundObj.loads[:m1], fundObj.loads[:m2]]])
			t.draw
			text "
			Характеристики грунтов"
			t = make_table(m1)
			t.draw
			
			text "
			среднее давление под подошвой фундамента  --  #{fundObj.p_sr.round(4)} тс/м2"
			text "
			давление под подошвой фундамента от собственного веса выбранного при отрывке котлована фундамента  --  #{fundObj.sigma_zg0.round(4)} тс/м2"
			text "
			Осадочная толща"
			text ig_layers1.hc.round(3).to_s + " м"
			
			text "
			Напряжения и осадка (послойная)"
			t = make_table(m2)
			t.draw
			text "
			Общая осадка - #{s_all.round(5)} м"
		end
	end
	# ------------------------------------------------------------------------------------------------------------------------------------------
	fundObj.listLayers = listLayers
	fundObj # возвращаем фундамент с инкапсулированным в него списков грунтов с посчитанными напряжениями

	end
end
ige1 = IGE.new(h = 3.6, gamma = 1.7, waterHold = "yes", e = 1800)
ige2 = IGE.new(h = 1.8, gamma = 1.7, waterHold = "no", e = 900)
ige3 = IGE.new(h = 8.5, gamma = 1.7, waterHold = "no", e = 1500)
listLayers1 = [ige1, ige2, ige3]
listLayers2 = [ige1, ige3.newH(5.0), ige2.newH(5.6)]
fund1 = SqBase.new("Fm1", l = 3.0, b = 2.0, h = 1.5, h_landing = 1.2, gamma_ = 1.8, loads = {nmax: 2, nmin: 1.2, q1: 2, q2: 1.5, m1: 2, m2: 1.5})
fund1.xy(0, 0) 
fund2 = SqBase.new("Fm2", l = 3.0, b = 2.0, h = 1.5, h_landing = 1.2, gamma_ = 1.8, loads = {nmax: 8, nmin: 1.2, q1: 2, q2: 1.5, m1: 2, m2: 1.5})
fund2.xy(5, 0)
fund3 = SqBase.new("Fm3", l = 3.0, b = 2.0, h = 1.5, h_landing = 1.2, gamma_ = 1.8, loads = {nmax: 12.3, nmin: 1.2, q1: 2, q2: 1.5, m1: 2, m2: 1.5})
fund3.xy(4, 0)
# здесь определим наборы данных для расчета, списки грунтов (скважины) и соотнесенные с ними списки фундаментов
h1 = {listLayers: listLayers1, fundList: [fund1]}
h2 = {listLayers: listLayers2, fundList: [fund2, fund3]}
# в массив FundAll =[] будем запихивать все вычисленные сущности 
FundAll =[]
sAll = Proc.new do |hashCalc| 
	hashCalc[:fundList].each{|fund| FundAll << Osadka.new(hashCalc[:listLayers].dup, fund) } 
end
# послали на расчет наборы данных
sAll.call(h1)
sAll.call(h2)
#Osadka.new(listLayers1.dup, fund1)
#Osadka.new(listLayers2.dup, fund2)
#Osadka.new(listLayers2.dup, fund3)

# настало вычислить добавочную осадку от других фундаментов
# в этот прок передается копия списка вычисленных фундаментов

# 
class SALL_add
	def xtoy point
		z = point[:x]
		point[:x] = point[:y]
		point[:y] = z
	end
	def fund2size_ev fund1, fund2 # тот на который влияют, тот тот который влияет
		fund_pull=[]
		dx = (fund2.x - fund1.x).abs
		dy = (fund2.y - fund1.y).abs
		# определим условные координаты влияющего фундамента относительно 0 (на который влияют)
		#
		#  p4   p3
		#
		#  p1   p2
		p1 = {x: dx - (fund2.l/2), y: dy - (fund2.b/2)}
		p2 = {x: dx + (fund2.l/2), y: dy - (fund2.b/2)}
		p3 = {x: dx + (fund2.l/2), y: dy + (fund2.b/2)}
		p4 = {x: dx - (fund2.l/2), y: dy + (fund2.b/2)}
		fund2.plist = {p1: p1, p2: p2, p3: p3, p4: p4}
		#определим размеры и число влияющих фундаментов
		
		# если какие-нибудь координаты 2 точек будут равны 0 - это будет первый случай, и влияемый фундамент будет разделен на 2
		fund2procx = Proc.new do |n1, n2, fund_vl|
			# f1, f2 - фундаменты на которые делится влияющий
			f1 = fund_vl.dup; f2 = fund_vl.dup
			f1.l = n1[:x].abs; f1.b = n1[:y].abs; f1.sign = '+' # учитываются знаки для влияющих фундаментов
			f2.l = n1[:x].abs; f2.b = n2[:y].abs; f2.sign = '-'
			[f1, f2]
			end
		fund2procxy = Proc.new do |fund_vl|
			if ((p1[:x] == 0 ) and (p4[:x] == 0)) then  
			fund_pull = fund2procx.call(fund_vl.plist[:p3], fund_vl.plist[:p1], fund_vl)
			break; end
			if ((p2[:x] == 0 ) and (p3[:x] == 0 )) then  
			fund_pull = fund2procx.call(fund_vl.plist[:p4], fund_vl.plist[:p1], fund_vl)
			break; end
		end
		fund2procxy.call(fund2)
		# если фундамент ближе к игриковой оси / зеркалим его по диагонали к Х
		self.xtoy p1; self.xtoy p2; self.xtoy p3; self.xtoy p4
		z = p1; p1 = p4; p4 = z
		# повторяем
		fund2procxy.call(fund2)

		# если первый случай не выполняется и  0 будет лежать между 2-мя координатами 2-х каких-либо точек по ближайшей либо дальней стороне
		# - 2-й случай (делится на 4 фундамента)
		fund4proc = Proc.new do 
			if (dx < (fund2.b/2)) then 
				fund3 = fund2.dup; fund3.plist = {p1:p1, p2:{x: 0, y: 0}, p3:{x: 0, y: 0}, p4: p4}
				fund4 = fund2.dup; fund4.plist = {p1:{x: 0, y: 0}, p2:p2, p3:p3, p4:{x: 0, y: 0}}
				fund_pull = fund2procxy.call(fund3) + fund2procxy.call(fund4)
			break; end
		end
		fund4proc.call()
		# опять
		# если фундамент ближе к игриковой оси / зеркалим его по диагонали к Х
		self.xtoy p1; self.xtoy p2; self.xtoy p3; self.xtoy p4
		z = p1; p1 = p4; p4 = z
		#---------------------------------------------------------------------
		# повторяем
		fund4proc.call()
		
		# если 2 случая выше не удовлетворяются значит выполняется третий случай и влияющий фундамент расположен по диогонали (делится на 4 фундамента)
		if (dx > (fund2.b/2)) and (dy > (fund2.b/2)) then
			f1 = fund2.dup; f1.l = p3[:x]; f1.b = p3[:y]; f1.sign = '+'
			f2 = fund2.dup; f2.l = p4[:x]; f2.b = p4[:y]; f2.sign = '-'
			f3 = fund2.dup; f3.l = p2[:x]; f3.b = p2[:y]; f3.sign = '-'
			f4 = fund2.dup; f4.l = p1[:x]; f4.b = p1[:y]; f4.sign = '+'
			fund_pull = [f1, f2, f3, f4]
		end
		# здесь идет блок кода - расчет добавочных напряжений от влияющих фундаментов и внедрение их в рассматр. фунд.
		# для этого бкрктся фундамент из пула, считаются в нем напряжения в пределах его сжимаемой толщи (в соответствии со знаком)
		# и делится на 4
	end
	def initialization fundList
		fundList.each do
			f = fundList.shift # в нем считается добавочная осадка
			fundList.each{|fundAd| self.fund2size_ev(f, fundAd)}
		end
	end
end