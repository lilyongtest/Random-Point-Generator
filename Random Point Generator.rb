require 'sketchup.rb'

module SU_VoronoiPoints_V19
  def self.generate_points
    model = Sketchup.active_model
    selection = model.selection
    faces = selection.grep(Sketchup::Face)
    
    if faces.empty?
      UI.messagebox("面を選択してください。")
      return
    end

    # ダイアログ設定
    # 密集度は「一辺の分割数」として扱います
    prompts = ["分割密度 (一辺あたりの数):", "ランダム度 (0-100%):"]
    defaults = [10.0, 50.0]
    input = UI.inputbox(prompts, defaults, "精密ボロノイ母点生成")
    return unless input
    
    divisions = input[0].to_i
    divisions = 1 if divisions < 1
    random_pct = input[1]
    randomness = [[random_pct / 100.0, 0.0].max, 1.0].min

    model.start_operation("Generate Scaled Points", true)
    entities = model.active_entities

    faces.each do |face|
      bbox = face.bounds
      min = bbox.min
      width = bbox.width
      height = bbox.height
      depth = bbox.depth

      # 面の向き（法線）を取得
      normal = face.normal
      
      # バウンディングボックスの最大辺に基づいてグリッドサイズを決定
      # これにより、100mmでも1000mmでも適切に分割されます
      max_side = [width, height, depth].max
      grid_size = max_side / divisions.to_f

      # 格子状にループ（ divisions より少し広めに走査して漏れを防ぐ）
      for i in 0..divisions
        for j in 0..divisions
          # ベースとなる格子の座標
          # 面がどの平面にあるかに依存するため、bboxの範囲で計算
          x_base = min.x + (i * (width / divisions.to_f))
          y_base = min.y + (j * (height / divisions.to_f))
          z_base = min.z + (j * (depth / divisions.to_f)) # 垂直面などの考慮

          # 揺らぎ（ジッター）を加える
          # 各軸に対してランダム移動
          off_x = (rand - 0.5) * grid_size * randomness
          off_y = (rand - 0.5) * grid_size * randomness
          off_z = (rand - 0.5) * grid_size * randomness
          
          test_pt = Geom::Point3d.new(x_base + off_x, y_base + off_y, z_base + off_z)
          
          # 点を面に投影
          projected_pt = test_pt.project_to_plane(face.plane)
          
          # 投影された点が面の内側にあるか判定
          if face.classify_point(projected_pt) == Sketchup::Face::PointInside || 
             face.classify_point(projected_pt) == Sketchup::Face::PointOnEdge
            entities.add_cpoint(projected_pt)
          end
        end
      end
    end

    model.commit_operation
  end
end

if not file_loaded?(__FILE__)
  UI.menu("Plugins").add_item("精密ボロノイ母点生成 (V19)") { SU_VoronoiPoints_V19.generate_points }
  file_loaded(__FILE__)
end