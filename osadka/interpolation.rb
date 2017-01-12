class Interpolation
	def index m, p
		count = 0
		m.each {|elem| 
			if elem >= p
				return count - 1
			else 
				count +=  1
			end
		}
		puts "
in index right limit achieved

m = #{m}, p = #{p}"
		puts " m = #{m}"
		puts " p = #{p}

		"
		raise IndexError, "in Interpolation.index - выход за пределы индекса, count - 1 = #{count - 1} > m.size = #{m.size}" if (count - 1) > m.size
		return count - 1 # на случай если p за пределами индекса
		#raise IndexError, "выход за пределы"
	end
	def int1d(m, x)
		x1 = m[0]
		y1 = m[1]
		x2 = m[2]
		y2 = m[3]
		tan = (y2 - y1)/(x2 - x1)
		z = tan*(x - x1) + y1
	end
	def int2d(main_m, xm, ym, x, y)
		#puts main_m
		x1index = self.index(xm, x)
		x2index = x1index + 1
		y1index = self.index(ym,y)
		#puts y1index
		raise ArgumentError, "ошибка аргумента - #{y1index}" if y1index.class == Array
		y2index = y1index + 1
		raise ArgumentError, "in int2d - ошибка аргумента, xm=#{xm}, ym=#{ym}, main_m=#{main_m}, x=#{x}, y=#{y}" if xm == [] || ym == [] || main_m == [] 
		#puts main_m, xm, ym
		m1 = [xm[x1index], main_m[y1index][x1index], xm[x2index], main_m[y1index][x2index]]
		m2 = [xm[x1index], main_m[y2index][x1index], xm[x2index], main_m[y2index][x2index]]
		z1 = self.int1d(m1, x)
		z2 = self.int1d(m2, x)
		m = [ym[y1index], z1, ym[y2index], z2]
		z = int1d(m, y)
	end
	def testSelf
		if self.index([1, 2, 3, 4], 3.1) == 2
			puts "index test -- Pass"
		else
			puts "index test -- Failure"
			puts self.index([1, 2, 3, 4], 3.1)
		end
			
		if (1.069 - self.int1d(m=[2.2, 1, 2.56, 1.25], x=2.3) < 0.0005)
			puts "int1d test -- Pass"
		else
			puts "int1d test -- Failure"
		end
	end
end

a = Interpolation.new
a.testSelf